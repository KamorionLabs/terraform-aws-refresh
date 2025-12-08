# terraform-aws-refresh - Project Status

> **Ce fichier est le point d'entrée pour reprendre le travail sur ce projet.**
> Mis à jour automatiquement lors des sessions de développement.

## Dernière mise à jour
- **Date:** 2025-12-09
- **Version:** v0.2.0
- **Session:** Modules cross-account et documentation

---

## Vue d'ensemble

Module Terraform pour orchestrer le refresh de bases de données Aurora/RDS et EFS entre comptes AWS (source production → destination non-prod) via AWS Step Functions.

### Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Shared Services Account                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    Orchestrator Step Function                        │    │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐            │    │
│  │  │    DB    │  │   EFS    │  │   EKS    │  │  Utils   │            │    │
│  │  │ 17 SFN   │  │  6 SFN   │  │  2 SFN   │  │  5 SFN   │            │    │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘            │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                    │                                         │
│                          AssumeRole (cross-account)                          │
└────────────────────────────────────┼────────────────────────────────────────┘
                                     │
          ┌──────────────────────────┼──────────────────────────┐
          │                          │                          │
          ▼                          ▼                          ▼
┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐
│   Source Account    │  │ Destination Account │  │ Destination Account │
│   (Production)      │  │   (Staging)         │  │   (Dev)             │
│                     │  │                     │  │                     │
│  source-account     │  │ destination-account │  │ destination-account │
│  module             │  │ module + Lambdas    │  │ module + Lambdas    │
└─────────────────────┘  └─────────────────────┘  └─────────────────────┘
```

### Modèle de déploiement

| Account | Module | Terraform State |
|---------|--------|-----------------|
| Shared Services | Root module | `shared-services/` |
| Production | `modules/source-account` | `production/` |
| Staging | `modules/destination-account` | `staging/` |
| Dev | `modules/destination-account` | `dev/` |

**Ordre de déploiement:**
1. Source + Destination accounts (en parallèle)
2. Shared Services (avec les ARNs des rôles créés)

---

## État actuel

### ✅ Complété

#### Module Database (17 Step Functions) - 100%
| Step Function | Description | Status |
|--------------|-------------|--------|
| `restore_cluster` | Restauration depuis snapshot cross-account | ✅ |
| `delete_cluster` | Suppression cluster destination | ✅ |
| `rename_cluster` | Renommage cluster | ✅ |
| `ensure_cluster_available` | Démarrage/attente disponibilité | ✅ |
| `ensure_cluster_not_exists` | Nettoyage clusters orphelins | ✅ |
| `stop_cluster` | Arrêt cluster après refresh | ✅ |
| `create_instance` | Création instances DB | ✅ |
| `share_snapshot` | Partage snapshot avec KMS grant | ✅ |
| `create_manual_snapshot` | Création snapshot manuel | ✅ |
| `list_shared_snapshots` | Liste snapshots partagés | ✅ |
| `enable_master_secret` | Activation master secret | ✅ |
| `rotate_secrets` | Rotation secrets après rename | ✅ |
| `configure_s3_integration` | Configuration accès S3 | ✅ |
| `run_sql_lambda` | Exécution SQL via Lambda | ✅ |
| `run_sql_from_s3` | Exécution SQL depuis S3 | ✅ |
| `run_mysqldump_on_eks` | Dump MySQL via EKS | ✅ |
| `run_mysqlimport_on_eks` | Import MySQL via EKS | ✅ |

#### Module EFS (6 Step Functions) - 100%
| Step Function | Description | Status |
|--------------|-------------|--------|
| `delete_filesystem` | Suppression EFS avec safety check | ✅ |
| `create_filesystem` | Création EFS destination | ✅ |
| `get_subpath_and_store_in_ssm` | Récupération subpath EFS | ✅ |
| `restore_from_backup` | Restauration depuis AWS Backup | ✅ |
| `setup_cross_account_replication` | Réplication EFS cross-account | ✅ |
| `wait_replication_complete` | Attente fin réplication | ✅ |

#### Module EKS (2 Step Functions) - 100%
| Step Function | Description | Status |
|--------------|-------------|--------|
| `manage_storage` | Gestion StorageClass, PV, PVC | ✅ |
| `scale_nodegroup_asg` | Scaling nodegroup ASG | ✅ |

#### Module Utils (5 Step Functions) - 100%
| Step Function | Description | Status |
|--------------|-------------|--------|
| `tag_resources` | Tagging des ressources | ✅ |
| `run_archive_job` | Archivage MySQL et media vers S3 | ✅ |
| `cleanup_and_stop` | Cleanup et arrêt parallèle | ✅ |
| `prepare_refresh` | Préparation refresh (noms, tags) | ✅ |
| `notify` | Notifications DynamoDB + SNS | ✅ |

#### Orchestrator (1 Step Function) - 100%
| Step Function | Description | Status |
|--------------|-------------|--------|
| `refresh_orchestrator` | Orchestrateur principal 3 phases | ✅ |

#### Modules Terraform Cross-Account - 100%
| Module | Description | Status |
|--------|-------------|--------|
| `modules/source-account` | Rôle IAM pour compte production | ✅ |
| `modules/destination-account` | Rôle IAM + Lambdas pour comptes non-prod | ✅ |
| `modules/iam` | Rôle orchestrateur (shared services) | ✅ |

#### Lambda Helpers - 100%
| Lambda | Description | Status |
|--------|-------------|--------|
| `run-sql` | Exécution SQL sur Aurora MySQL | ✅ |
| `get-efs-subpath` | Recherche répertoire backup dans EFS | ✅ |
| `pymysql` layer | Layer Python pour PyMySQL | ✅ |

#### Infrastructure Terraform - 100%
- [x] Structure du module Terraform Registry compliant
- [x] Module IAM (orchestrator role avec ARNs en input)
- [x] Module Step Functions (DB, EFS, EKS, Utils, Orchestrator)
- [x] Module source-account (rôle + policies)
- [x] Module destination-account (rôle + policies + lambdas + EKS access entry)
- [x] Variables et outputs
- [x] README complet avec exemples

#### Tests CI/CD
- [x] Script de validation ASL (Python)
- [x] Tests pytest pour validation structurelle
- [x] Tests Step Functions Local (Docker)
- [x] GitHub Actions workflow

### ❌ À faire

#### Tests
- [ ] Tests unitaires Terraform (terraform validate)
- [ ] Tests d'intégration end-to-end
- [ ] Exemple de déploiement complet multi-compte

---

## Structure du dépôt

```
terraform-aws-refresh/
├── main.tf                    # Module principal
├── variables.tf               # Variables d'entrée (source/dest role ARNs)
├── outputs.tf                 # Sorties du module
├── versions.tf                # Versions Terraform/providers
├── README.md                  # Documentation complète
├── PROJECT_STATUS.md          # Ce fichier (suivi projet)
│
├── modules/
│   ├── step-functions/
│   │   ├── db/                # ✅ 17 Step Functions DB
│   │   │   └── *.asl.json
│   │   ├── efs/               # ✅ 6 Step Functions EFS
│   │   │   └── *.asl.json
│   │   ├── eks/               # ✅ 2 Step Functions EKS
│   │   │   └── *.asl.json
│   │   ├── utils/             # ✅ 5 Step Functions Utils
│   │   │   └── *.asl.json
│   │   └── orchestrator/      # ✅ 1 Orchestrateur principal
│   │       └── *.asl.json
│   │
│   ├── iam/                   # ✅ Rôle orchestrateur
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── source-account/        # ✅ Module compte source (production)
│   │   ├── main.tf            # IAM role + policies
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── versions.tf
│   │
│   └── destination-account/   # ✅ Module compte destination (non-prod)
│       ├── main.tf            # IAM role + policies + EKS access entry
│       ├── lambdas.tf         # Lambda functions (run-sql, get-efs-subpath)
│       ├── variables.tf
│       ├── outputs.tf
│       └── versions.tf
│
├── lambdas/
│   ├── run-scripts-mysql/
│   │   └── run_sql.py         # ✅ Lambda exécution SQL
│   ├── get-efs-subpath/
│   │   └── get_efs_subpath.py # ✅ Lambda recherche backup EFS
│   └── layers/
│       └── pymysql/
│           └── requirements.txt # ✅ PyMySQL layer
│
├── scripts/
│   └── validate_asl.py        # ✅ Validateur ASL Python
│
├── tests/
│   ├── conftest.py            # ✅ Fixtures pytest
│   ├── test_asl_validation.py # ✅ Tests validation ASL
│   └── test_stepfunctions_local.py # ✅ Tests Docker SF Local
│
├── .github/
│   └── workflows/
│       └── step-functions.yml # ✅ CI/CD GitHub Actions
│
├── examples/
│   ├── simple/                # Exemple simple
│   └── complete/              # Exemple complet
│
└── requirements-dev.txt       # ✅ Dépendances tests Python
```

---

## Comment utiliser ce module

### Déploiement en 3 étapes

#### Étape 1: Compte Source (Production)

```hcl
# deployments/production/main.tf
module "refresh_source" {
  source  = "KamorionLabs/refresh/aws//modules/source-account"
  version = "0.2.0"

  prefix                = "myapp-refresh"
  orchestrator_role_arn = "arn:aws:iam::000000000000:role/myapp-refresh-orchestrator"

  tags = { Project = "database-refresh" }
}

output "role_arn" {
  value = module.refresh_source.role_arn
}
```

#### Étape 2: Comptes Destination (Staging, Dev...)

```hcl
# deployments/staging/main.tf
module "refresh_destination" {
  source  = "KamorionLabs/refresh/aws//modules/destination-account"
  version = "0.2.0"

  prefix                = "myapp-refresh"
  orchestrator_role_arn = "arn:aws:iam::000000000000:role/myapp-refresh-orchestrator"

  deploy_lambdas = true
  vpc_id         = "vpc-xxx"
  subnet_ids     = ["subnet-xxx", "subnet-yyy"]

  # EKS Access Entry (optionnel)
  create_eks_access_entry = true
  eks_cluster_name        = "my-cluster"

  tags = { Project = "database-refresh" }
}

output "role_arn" {
  value = module.refresh_destination.role_arn
}
```

#### Étape 3: Compte Shared Services (Orchestrateur)

```hcl
# deployments/shared-services/main.tf
module "refresh" {
  source  = "KamorionLabs/refresh/aws"
  version = "0.2.0"

  prefix = "myapp-refresh"

  # ARNs des rôles créés aux étapes 1 et 2
  source_role_arns = [
    "arn:aws:iam::111111111111:role/myapp-refresh-source-role"
  ]
  destination_role_arns = [
    "arn:aws:iam::222222222222:role/myapp-refresh-destination-role",
    "arn:aws:iam::333333333333:role/myapp-refresh-destination-role"
  ]

  tags = { Project = "database-refresh" }
}
```

---

## Sessions de développement

### 2025-12-09 - Modules cross-account et documentation
**Objectif:** Finaliser les modules pour déploiement multi-compte

**Réalisé:**
1. ✅ Module `source-account`
   - IAM role avec policies RDS snapshot, KMS, EFS, Secrets Manager
   - Support rôle existant (`create_role = false`)
2. ✅ Module `destination-account`
   - IAM role avec policies complètes (RDS, EFS, EKS, Lambda, S3, SSM, Backup)
   - Lambda helpers (run-sql, get-efs-subpath) avec VPC config
   - EKS Access Entry pour accès Kubernetes
   - Support rôle existant
3. ✅ Refactoring module IAM
   - Variables `source_role_arns` / `destination_role_arns` (ARNs en input)
   - Suppression génération automatique des ARNs
4. ✅ Fixes ASL/Lambda
   - Correction paramètres run_sql_lambda.asl.json
   - Correction chemin get_subpath_and_store_in_ssm.asl.json (`.subpath` vs `[0]`)
   - Ajout permission `backup:ListRecoveryPointsByResource`
5. ✅ Documentation
   - README complet avec workflow déploiement 3 étapes
   - PROJECT_STATUS mis à jour

**Version:** v0.2.0 (breaking change - role ARNs en input)

### 2025-12-08 - Complétion des Step Functions
**Objectif:** Compléter tous les modules Step Functions ASL

**Réalisé:**
1. ✅ Module EFS complet (6 Step Functions)
2. ✅ Module EKS complet (2 Step Functions)
3. ✅ Module Utils complet (5 Step Functions)
4. ✅ Orchestrateur principal
5. ✅ Tests CI/CD (validation ASL, pytest, GitHub Actions)

**Stats:** 31 Step Functions ASL validées

### 2025-12-08 - Initialisation
**Objectif:** Créer le nouveau dépôt propre depuis le sandbox legacy

**Réalisé:**
1. ✅ Création dépôt `terraform-aws-refresh`
2. ✅ Structure Terraform module registry compliant
3. ✅ Migration 17 Step Functions DB depuis sandbox
4. ✅ Module IAM avec policies cross-account
5. ✅ Module Step Functions DB complet

---

## Notes techniques

### Cross-Account Credentials
Chaque Step Function utilise `Credentials.RoleArn` pour les opérations cross-account :
```json
{
  "Type": "Task",
  "Resource": "arn:aws:states:::aws-sdk:rds:describeDBClusters",
  "Credentials": {
    "RoleArn.$": "$.DestinationAccount.RoleArn"
  }
}
```

### Format d'input standard
```json
{
  "SourceAccount": {
    "AccountId": "111111111111",
    "RoleArn": "arn:aws:iam::111111111111:role/refresh-source-role"
  },
  "DestinationAccount": {
    "AccountId": "222222222222",
    "RoleArn": "arn:aws:iam::222222222222:role/refresh-destination-role"
  },
  "DbClusterIdentifier": "my-cluster",
  ...
}
```

### Lambda Helpers
| Lambda | Runtime | Layers | VPC |
|--------|---------|--------|-----|
| `run-sql` | Python 3.11 | pymysql | Oui |
| `get-efs-subpath` | Python 3.11 | - | Oui (avec EFS mount) |

### Permissions IAM par compte
| Compte | Services | Niveau |
|--------|----------|--------|
| Source | RDS, KMS, EFS, Secrets, Tags | Read + Snapshot |
| Destination | RDS, EFS, EKS, Lambda, S3, SSM, Secrets, Backup, Tags | Full |
| Orchestrator | Step Functions, STS (AssumeRole) | Execute + Assume |

---

## Références

- [AWS Step Functions Credentials](https://docs.aws.amazon.com/step-functions/latest/dg/connect-to-resource.html#connect-credentials)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/)
- [RDS Snapshot Sharing](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ShareSnapshot.html)
- [EKS Access Entries](https://docs.aws.amazon.com/eks/latest/userguide/access-entries.html)

---

## Releases

| Version | Date | Description |
|---------|------|-------------|
| v0.2.0 | 2025-12-09 | **Breaking:** Role ARNs en input, modules cross-account, lambdas |
| v0.1.0 | - | (supprimée, remplacée par v0.2.0) |

---

## Contact

**Projet:** terraform-aws-refresh
**Registry:** `KamorionLabs/refresh/aws`
**Maintainer:** KamorionLabs
