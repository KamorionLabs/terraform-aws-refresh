# terraform-aws-refresh - Project Status

> **Ce fichier est le point d'entrée pour reprendre le travail sur ce projet.**
> Mis à jour automatiquement lors des sessions de développement.

## Dernière mise à jour
- **Date:** 2025-12-08
- **Session:** Initialisation du dépôt et migration depuis sandbox

---

## Vue d'ensemble

Module Terraform pour orchestrer le refresh de bases de données Aurora/RDS entre comptes AWS (source production → destination non-prod) via AWS Step Functions.

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Shared Services Account (Orchestrator)                     │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Step Functions (17 DB + EFS + EKS + Utils)           │  │
│  │  IAM Role: refresh-orchestrator-role                  │  │
│  └───────────────────────────────────────────────────────┘  │
│                            │                                │
│         AssumeRole ────────┼────────── AssumeRole           │
│                            │                                │
└────────────────────────────┼────────────────────────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ Prod Account │    │ Staging Acct │    │ Preprod Acct │
│              │    │              │    │              │
│ SOURCE       │    │ DESTINATION  │    │ DESTINATION  │
│ (Read-Only)  │    │ (Full Access)│    │ (Full Access)│
└──────────────┘    └──────────────┘    └──────────────┘
```

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

#### Infrastructure Terraform
- [x] Structure du module Terraform
- [x] Module IAM (orchestrator role)
- [x] Module Step Functions DB
- [x] Variables et outputs

### 🚧 En cours

#### Module EFS (1/6 Step Functions) - 17%
| Step Function | Description | Status |
|--------------|-------------|--------|
| `delete_filesystem` | Suppression EFS avec safety check | ✅ |
| `create_filesystem` | Création EFS destination | ❌ |
| `get_subpath_and_store_in_ssm` | Récupération subpath EFS | ❌ |
| `restore_from_backup` | Restauration depuis AWS Backup | ❌ |
| `setup_cross_account_replication` | Réplication EFS cross-account | ❌ |
| `wait_replication_complete` | Attente fin réplication | ❌ |

### ❌ À faire

#### Module EKS (0/2)
- [ ] `manage_storage` - Gestion storage EKS
- [ ] `scale_nodegroup_asg` - Scaling nodegroup ASG

#### Module Utils (0/5)
- [ ] `tag_resources` - Tagging des ressources
- [ ] `run_archive_job` - Archivage
- [ ] `cleanup_and_stop` - Cleanup et arrêt
- [ ] `prepare_refresh` - Préparation refresh
- [ ] `notify` - Notifications SNS

#### Orchestrator (0/1)
- [ ] `refresh_orchestrator` - Orchestrateur principal

#### Tests
- [ ] Tests unitaires Terraform
- [ ] Tests d'intégration Step Functions
- [ ] Validation cross-account

---

## Structure du dépôt

```
terraform-aws-refresh/
├── main.tf                    # Module principal
├── variables.tf               # Variables d'entrée
├── outputs.tf                 # Sorties du module
├── versions.tf                # Versions Terraform/providers
├── PROJECT_STATUS.md          # Ce fichier (suivi projet)
│
├── modules/
│   ├── step-functions/
│   │   ├── db/                # ✅ 17 Step Functions DB
│   │   │   ├── *.asl.json     # Définitions ASL
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   ├── efs/               # 🚧 Step Functions EFS
│   │   ├── eks/               # ❌ Step Functions EKS
│   │   └── utils/             # ❌ Step Functions Utils
│   │
│   ├── iam/                   # ✅ Rôles IAM cross-account
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   └── orchestrator/          # ❌ Orchestrateur principal
│
├── examples/
│   ├── simple/                # Exemple simple
│   └── complete/              # Exemple complet
│
└── tests/                     # Tests
```

---

## Comment utiliser ce module

### Exemple minimal

```hcl
module "refresh" {
  source = "git::https://github.com/ORG/terraform-aws-refresh.git"

  prefix      = "myapp"
  environment = "shared"

  source_account_id       = "111111111111"  # Compte prod
  destination_account_ids = [
    "222222222222",  # Staging
    "333333333333"   # Preprod
  ]

  tags = {
    Project = "database-refresh"
  }
}
```

### Déploiement des rôles dans les comptes

```bash
# 1. Déployer dans le compte orchestrateur (shared services)
terraform apply

# 2. Récupérer les policies pour les autres comptes
terraform output source_role_policy > source-role-policy.json
terraform output destination_role_policy > destination-role-policy.json

# 3. Créer les rôles dans source/destination accounts
# (via Terraform séparé ou manuellement)
```

---

## Sessions de développement

### 2025-12-08 - Initialisation
**Objectif:** Créer le nouveau dépôt propre depuis le sandbox legacy

**Réalisé:**
1. ✅ Création dépôt `terraform-aws-refresh`
2. ✅ Structure Terraform module registry compliant
3. ✅ Migration 17 Step Functions DB depuis sandbox
4. ✅ Module IAM avec policies cross-account
5. ✅ Module Step Functions DB complet

**Prochaines étapes:**
1. Compléter module EFS (5 Step Functions restantes)
2. Créer module EKS (2 Step Functions)
3. Créer module Utils (5 Step Functions)
4. Créer orchestrateur principal
5. Tests et validation

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

### KMS pour snapshots chiffrés
La Step Function `share_snapshot` crée automatiquement un KMS grant pour permettre au compte destination de déchiffrer les snapshots chiffrés.

---

## Références

- [AWS Step Functions Credentials](https://docs.aws.amazon.com/step-functions/latest/dg/connect-to-resource.html#connect-credentials)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/)
- [RDS Snapshot Sharing](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ShareSnapshot.html)

---

## Contact

**Projet:** terraform-aws-refresh
**Maintainer:** Kamorion
