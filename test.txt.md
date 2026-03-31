# Kubernetes Secrets → AWS Secrets Manager → CSI Driver → Pod Mount

## README

## Overview

This setup exports Kubernetes secrets from all namespaces into AWS Secrets Manager and mounts them inside pods using the Secrets Store CSI Driver with IAM Roles for Service Accounts (IRSA).
This allows you to manage secrets centrally in AWS instead of storing them directly in Kubernetes etcd.

---

## Architecture Flow

```
Kubernetes Secret
        ↓
Export Script
        ↓
AWS Secrets Manager
        ↓
IAM Role (IRSA)
        ↓
Secrets Store CSI Driver
        ↓
Mounted into Pod as Files
```

---

## Components Used

| Component                             | Purpose                             |
| ------------------------------------- | ----------------------------------- |
| Kubernetes                            | Runs workloads                      |
| AWS Secrets Manager                   | Stores secrets securely             |
| Secrets Store CSI Driver              | Mounts secrets into pods            |
| AWS CSI Provider                      | Connects CSI to AWS Secrets Manager |
| IAM Roles for Service Accounts (IRSA) | Secure AWS access from pods         |
| Bash Script                           | Exports K8s secrets to AWS          |

---

## Step 1 — Install Secrets Store CSI Driver

```bash
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm install -n kube-system csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver
```

Install AWS provider:

```bash
helm repo add aws-secrets-manager https://aws.github.io/secrets-store-csi-driver-provider-aws
helm install -n kube-system secrets-provider-aws aws-secrets-manager/secrets-store-csi-driver-provider-aws
```

---

## Step 2 — Export Kubernetes Secrets to AWS

Script exports all namespace secrets (except service account tokens) and pushes them to AWS Secrets Manager.

### Script

```bash
#!/usr/bin/env bash

set -euo pipefail
ENVIRONMENT="prod"
AWS_REGION="${AWS_REGION:-us-east-1}"
OUTPUT_DIR="./"

echo "Using AWS region: $AWS_REGION"
echo "Fetching namespaces..."

NAMESPACES=$(kubectl get ns -o jsonpath='{.items[*].metadata.name}')

for NS in $NAMESPACES; do
    echo "Processing namespace: $NS"

    mkdir -p "$OUTPUT_DIR/$NS"

    DECODED_JSON=$(kubectl get secrets -n "$NS" -o json | jq '
      .items
      | map(select(.type != "kubernetes.io/service-account-token"))
      | map({
          name: .metadata.name,
          type: .type,
          data: (.data | map_values(@base64d))
        })
    ')

    echo "$DECODED_JSON" | jq . > "$OUTPUT_DIR/$NS/secrets.json"

    AWS_SECRET_NAME="k8s/${ENVIRONMENT}/${NS}/secrets"

    if aws secretsmanager describe-secret \
        --region "$AWS_REGION" \
        --secret-id "$AWS_SECRET_NAME" >/dev/null 2>&1; then

        aws secretsmanager put-secret-value \
            --region "$AWS_REGION" \
            --secret-id "$AWS_SECRET_NAME" \
            --secret-string "$DECODED_JSON" >/dev/null
    else
        aws secretsmanager create-secret \
            --region "$AWS_REGION" \
            --name "$AWS_SECRET_NAME" \
            --secret-string "$DECODED_JSON" >/dev/null
    fi

    echo "Namespace $NS synced to AWS."
done

echo "All namespaces exported and pushed."
```

---

## Step 3 — IAM Policy for Secrets Manager Access

Create IAM policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:secretsmanager:us-east-1:<ACCOUNT_ID>:secret:k8s/prod/*"
    }
  ]
}
```

---

## Step 4 — Create IAM Role for IRSA

Trust relationship:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/<EKS_OIDC_PROVIDER>"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "<EKS_OIDC_PROVIDER>:sub": "system:serviceaccount:<namespace>:aws-secrets-sa"
        }
      }
    }
  ]
}
```

Attach the Secrets Manager policy to this role.

---

## Step 5 — Create Kubernetes Service Account

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-secrets-sa
  namespace: myapp
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::<ACCOUNT_ID>:role/secrets-manager-role
```

---

## Step 6 — Create SecretProviderClass

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: aws-secrets
  namespace: myapp
spec:
  provider: aws
  parameters:
    objects: |
      - objectName: "k8s/prod/myapp/secrets"
        objectType: "secretsmanager"
```

---

## Step 7 — Mount Secret in Deployment

```yaml
spec:
  serviceAccountName: aws-secrets-sa
  volumes:
    - name: secrets
      csi:
        driver: secrets-store.csi.k8s.io
        readOnly: true
        volumeAttributes:
          secretProviderClass: aws-secrets
  containers:
    - name: app
      image: nginx
      volumeMounts:
        - name: secrets
          mountPath: "/mnt/secrets"
```

Secrets will be available inside the container at:

```
/mnt/secrets/
```

---

## Secret Naming Convention

Recommended structure:

```
k8s/<environment>/<namespace>/<secret_name>
```

Example:

```
k8s/prod/payment/db-secret
k8s/prod/auth/jwt-secret
k8s/prod/frontend/api-key
```

This allows fine-grained access control per application.

---

## Security Best Practices

* Do NOT give Secrets Manager access to node IAM role
* Use IRSA only
* Restrict IAM policy to specific secret paths
* Enable secret rotation if possible
* Enable CloudTrail logging for Secrets Manager
* Limit access per namespace/service account

---

## Troubleshooting

| Issue                  | Fix                       |
| ---------------------- | ------------------------- |
| Secrets not mounting   | Check SecretProviderClass |
| Access denied          | Check IAM policy          |
| Empty mount            | Check secret name path    |
| IRSA not working       | Check OIDC provider       |
| Pod cannot read secret | Check serviceAccountName  |

---

## Verification

Exec into pod:

```bash
kubectl exec -it <pod> -- ls /mnt/secrets
kubectl exec -it <pod> -- cat /mnt/secrets/k8s/prod/myapp/secrets
```

---

## Summary

This setup provides:

* Centralized secret management
* No secrets stored in Kubernetes etcd
* IAM-based access control
* Automatic secret mounting into pods
* Works with EKS using IRSA

```
```
