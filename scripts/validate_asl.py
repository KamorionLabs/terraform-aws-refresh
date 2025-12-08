#!/usr/bin/env python3
"""
ASL (Amazon States Language) Local Validator

Validates AWS Step Functions state machine definitions locally without AWS credentials.
Checks:
- JSON syntax validity
- Required ASL fields (StartAt, States)
- State type validity
- State references integrity (Next, Default, Catch)
- Terminal states existence
- Cross-account credentials patterns
- Unreachable states detection

Inspired by:
- https://github.com/awslabs/statelint (Ruby)
- https://github.com/ChristopheBougere/asl-validator (Node.js)
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Any


class ASLValidationError(Exception):
    """Custom exception for ASL validation errors."""
    pass


class ASLValidator:
    """Validates ASL state machine definitions locally."""

    VALID_STATE_TYPES = {
        "Task", "Pass", "Choice", "Wait", "Succeed", "Fail", "Parallel", "Map"
    }

    TERMINAL_STATE_TYPES = {"Succeed", "Fail"}

    # States that don't need Next or End
    NO_TRANSITION_TYPES = {"Choice", "Succeed", "Fail"}

    def __init__(self, file_path: str):
        self.file_path = file_path
        self.errors: list[str] = []
        self.warnings: list[str] = []
        self.info: list[str] = []
        self.definition: dict[str, Any] = {}

    def load(self) -> bool:
        """Load and parse the ASL JSON file."""
        try:
            with open(self.file_path, 'r', encoding='utf-8') as f:
                self.definition = json.load(f)
            return True
        except json.JSONDecodeError as e:
            self.errors.append(f"Invalid JSON syntax: {e}")
            return False
        except FileNotFoundError:
            self.errors.append(f"File not found: {self.file_path}")
            return False
        except Exception as e:
            self.errors.append(f"Error reading file: {e}")
            return False

    def validate(self) -> bool:
        """Run all validations."""
        if not self.load():
            return False

        self._validate_required_fields()
        self._validate_start_at()
        self._validate_states()
        self._validate_state_references()
        self._validate_terminal_states()
        self._detect_unreachable_states()
        self._check_cross_account_patterns()
        self._check_hardcoded_arns()

        return len(self.errors) == 0

    def _validate_required_fields(self):
        """Check for required top-level fields."""
        if "StartAt" not in self.definition:
            self.errors.append("Missing required field: 'StartAt'")

        if "States" not in self.definition:
            self.errors.append("Missing required field: 'States'")
        elif not isinstance(self.definition["States"], dict):
            self.errors.append("'States' must be an object")
        elif len(self.definition["States"]) == 0:
            self.errors.append("'States' cannot be empty")

    def _validate_start_at(self):
        """Validate that StartAt references an existing state."""
        if "StartAt" not in self.definition or "States" not in self.definition:
            return

        start_at = self.definition["StartAt"]
        states = self.definition.get("States", {})

        if start_at not in states:
            self.errors.append(f"'StartAt' references non-existent state: '{start_at}'")

    def _validate_states(self):
        """Validate individual state definitions."""
        states = self.definition.get("States", {})

        for state_name, state_def in states.items():
            if not isinstance(state_def, dict):
                self.errors.append(f"State '{state_name}' must be an object")
                continue

            state_type = state_def.get("Type")
            if not state_type:
                self.errors.append(f"State '{state_name}' missing 'Type' field")
                continue

            if state_type not in self.VALID_STATE_TYPES:
                self.errors.append(f"State '{state_name}' has invalid type: '{state_type}'")
                continue

            # Check for End or Next (except for Choice, Succeed, Fail)
            if state_type not in self.NO_TRANSITION_TYPES:
                has_end = state_def.get("End", False)
                has_next = "Next" in state_def
                if not has_end and not has_next:
                    self.errors.append(f"State '{state_name}' (Type: {state_type}) must have 'End: true' or 'Next'")

            # Validate specific state types
            if state_type == "Choice":
                self._validate_choice_state(state_name, state_def)
            elif state_type == "Task":
                self._validate_task_state(state_name, state_def)
            elif state_type == "Wait":
                self._validate_wait_state(state_name, state_def)
            elif state_type == "Map":
                self._validate_map_state(state_name, state_def)
            elif state_type == "Parallel":
                self._validate_parallel_state(state_name, state_def)

    def _validate_choice_state(self, state_name: str, state_def: dict):
        """Validate Choice state structure."""
        if "Choices" not in state_def:
            self.errors.append(f"Choice state '{state_name}' missing required 'Choices' field")
            return

        choices = state_def["Choices"]
        if not isinstance(choices, list):
            self.errors.append(f"Choice state '{state_name}': 'Choices' must be an array")
            return

        if len(choices) == 0:
            self.errors.append(f"Choice state '{state_name}': 'Choices' array cannot be empty")

        for i, choice in enumerate(choices):
            if "Next" not in choice:
                self.errors.append(f"Choice state '{state_name}' choice[{i}] missing 'Next' field")

        if "Default" not in state_def:
            self.warnings.append(f"Choice state '{state_name}' has no 'Default' - may fail at runtime if no choice matches")

    def _validate_task_state(self, state_name: str, state_def: dict):
        """Validate Task state structure."""
        if "Resource" not in state_def:
            self.errors.append(f"Task state '{state_name}' missing required 'Resource' field")

        # Check for error handling
        has_catch = "Catch" in state_def
        has_retry = "Retry" in state_def

        if not has_catch and not has_retry:
            self.warnings.append(f"Task state '{state_name}' has no error handling (Catch/Retry)")

    def _validate_wait_state(self, state_name: str, state_def: dict):
        """Validate Wait state structure."""
        wait_fields = ["Seconds", "SecondsPath", "Timestamp", "TimestampPath"]
        has_wait_field = any(f in state_def for f in wait_fields)

        if not has_wait_field:
            self.errors.append(f"Wait state '{state_name}' must have one of: {', '.join(wait_fields)}")

    def _validate_map_state(self, state_name: str, state_def: dict):
        """Validate Map state structure."""
        # Map state needs either ItemProcessor (new) or Iterator (legacy)
        has_item_processor = "ItemProcessor" in state_def
        has_iterator = "Iterator" in state_def

        if not has_item_processor and not has_iterator:
            self.errors.append(f"Map state '{state_name}' missing 'ItemProcessor' or 'Iterator'")

    def _validate_parallel_state(self, state_name: str, state_def: dict):
        """Validate Parallel state structure."""
        if "Branches" not in state_def:
            self.errors.append(f"Parallel state '{state_name}' missing required 'Branches' field")
            return

        branches = state_def["Branches"]
        if not isinstance(branches, list) or len(branches) == 0:
            self.errors.append(f"Parallel state '{state_name}': 'Branches' must be a non-empty array")

    def _validate_state_references(self):
        """Validate all state references (Next, Default, Catch, etc.)."""
        states = self.definition.get("States", {})
        valid_states = set(states.keys())

        for state_name, state_def in states.items():
            if not isinstance(state_def, dict):
                continue

            # Check Next reference
            if "Next" in state_def:
                next_state = state_def["Next"]
                if next_state not in valid_states:
                    self.errors.append(f"State '{state_name}' 'Next' references non-existent state: '{next_state}'")

            # Check Choice transitions
            if state_def.get("Type") == "Choice":
                for i, choice in enumerate(state_def.get("Choices", [])):
                    if "Next" in choice and choice["Next"] not in valid_states:
                        self.errors.append(f"Choice state '{state_name}' choice[{i}] references non-existent state: '{choice['Next']}'")

                if "Default" in state_def and state_def["Default"] not in valid_states:
                    self.errors.append(f"Choice state '{state_name}' 'Default' references non-existent state: '{state_def['Default']}'")

            # Check Catch transitions
            for i, catch in enumerate(state_def.get("Catch", [])):
                if "Next" in catch and catch["Next"] not in valid_states:
                    self.errors.append(f"State '{state_name}' Catch[{i}] references non-existent state: '{catch['Next']}'")

    def _validate_terminal_states(self):
        """Check that there's at least one reachable terminal state."""
        states = self.definition.get("States", {})

        terminal_states = []
        for state_name, state_def in states.items():
            if not isinstance(state_def, dict):
                continue

            state_type = state_def.get("Type", "")
            if state_type in self.TERMINAL_STATE_TYPES or state_def.get("End", False):
                terminal_states.append(state_name)

        if not terminal_states:
            self.errors.append("No terminal state found - workflow will never complete (need 'End: true', 'Succeed', or 'Fail' state)")

    def _detect_unreachable_states(self):
        """Detect states that cannot be reached from StartAt."""
        states = self.definition.get("States", {})
        start_at = self.definition.get("StartAt")

        if not states or not start_at:
            return

        # BFS to find all reachable states
        reachable = set()
        queue = [start_at]

        while queue:
            current = queue.pop(0)
            if current in reachable or current not in states:
                continue

            reachable.add(current)
            state_def = states[current]

            if not isinstance(state_def, dict):
                continue

            # Collect next states
            next_states = []

            if "Next" in state_def:
                next_states.append(state_def["Next"])

            if state_def.get("Type") == "Choice":
                for choice in state_def.get("Choices", []):
                    if "Next" in choice:
                        next_states.append(choice["Next"])
                if "Default" in state_def:
                    next_states.append(state_def["Default"])

            for catch in state_def.get("Catch", []):
                if "Next" in catch:
                    next_states.append(catch["Next"])

            # Parallel branches
            for branch in state_def.get("Branches", []):
                if isinstance(branch, dict) and "StartAt" in branch:
                    # Note: branch states are in their own namespace, skip for now
                    pass

            queue.extend(next_states)

        unreachable = set(states.keys()) - reachable
        for state in unreachable:
            self.warnings.append(f"State '{state}' is unreachable from StartAt")

    def _check_cross_account_patterns(self):
        """Check for cross-account credential patterns."""
        states = self.definition.get("States", {})
        credentials_count = 0

        for state_name, state_def in states.items():
            if not isinstance(state_def, dict):
                continue

            if "Credentials" in state_def:
                credentials_count += 1
                creds = state_def["Credentials"]
                if "RoleArn" not in creds and "RoleArn.$" not in creds:
                    self.warnings.append(f"State '{state_name}' has Credentials but no RoleArn")

        if credentials_count > 0:
            self.info.append(f"Cross-account pattern detected: {credentials_count} states with Credentials")

    def _check_hardcoded_arns(self):
        """Check for hardcoded AWS account IDs in ARNs."""
        content = json.dumps(self.definition)

        import re
        # Match ARNs with hardcoded 12-digit account IDs
        pattern = r'arn:aws:[a-z0-9-]+:[a-z0-9-]*:(\d{12}):'
        matches = re.findall(pattern, content)

        if matches:
            unique_accounts = set(matches)
            self.warnings.append(f"Hardcoded AWS account ID(s) found: {', '.join(unique_accounts)} - consider using parameters")

    def report(self, verbose: bool = False) -> str:
        """Generate validation report."""
        lines = [f"File: {self.file_path}"]

        if self.errors:
            lines.append(f"  ERRORS ({len(self.errors)}):")
            for error in self.errors:
                lines.append(f"    ✗ {error}")

        if self.warnings and verbose:
            lines.append(f"  WARNINGS ({len(self.warnings)}):")
            for warning in self.warnings:
                lines.append(f"    ⚠ {warning}")

        if self.info and verbose:
            lines.append(f"  INFO ({len(self.info)}):")
            for info in self.info:
                lines.append(f"    ℹ {info}")

        if not self.errors:
            lines.append("  ✓ Valid")

        return "\n".join(lines)


def find_asl_files(root_dir: str = ".") -> list[str]:
    """Find all .asl.json files in directory tree."""
    asl_files = []
    for path in Path(root_dir).rglob("*.asl.json"):
        # Skip hidden directories and common excludes
        if any(part.startswith('.') for part in path.parts):
            continue
        if 'node_modules' in path.parts or '.terraform' in path.parts:
            continue
        asl_files.append(str(path))
    return sorted(asl_files)


def main():
    parser = argparse.ArgumentParser(
        description="Validate AWS Step Functions ASL definitions locally"
    )
    parser.add_argument(
        "files",
        nargs="*",
        help="ASL files to validate (default: find all *.asl.json)"
    )
    parser.add_argument(
        "-d", "--directory",
        default=".",
        help="Root directory to search for ASL files (default: current)"
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Show warnings and info messages"
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Treat warnings as errors"
    )
    parser.add_argument(
        "-q", "--quiet",
        action="store_true",
        help="Only output on errors"
    )

    args = parser.parse_args()

    # Get files to validate
    if args.files:
        asl_files = args.files
    else:
        asl_files = find_asl_files(args.directory)

    if not asl_files:
        if not args.quiet:
            print("No .asl.json files found")
        sys.exit(0)

    if not args.quiet:
        print("=" * 60)
        print("ASL (Amazon States Language) Validator")
        print("=" * 60)
        print(f"Found {len(asl_files)} ASL file(s)\n")

    total_errors = 0
    total_warnings = 0
    failed_files = []

    for file_path in asl_files:
        validator = ASLValidator(file_path)
        is_valid = validator.validate()

        if args.strict:
            is_valid = is_valid and len(validator.warnings) == 0

        if not args.quiet or not is_valid:
            print(validator.report(verbose=args.verbose))
            print()

        total_errors += len(validator.errors)
        total_warnings += len(validator.warnings)

        if not is_valid:
            failed_files.append(file_path)

    # Summary
    if not args.quiet:
        print("=" * 60)
        print("Summary")
        print("=" * 60)
        print(f"Files validated: {len(asl_files)}")
        print(f"Files passed:    {len(asl_files) - len(failed_files)}")
        print(f"Files failed:    {len(failed_files)}")
        print(f"Total errors:    {total_errors}")
        print(f"Total warnings:  {total_warnings}")

    if failed_files:
        if not args.quiet:
            print("\nFailed files:")
            for f in failed_files:
                print(f"  - {f}")
        sys.exit(1)
    else:
        if not args.quiet:
            print("\n✓ All ASL files are valid")
        sys.exit(0)


if __name__ == "__main__":
    main()
