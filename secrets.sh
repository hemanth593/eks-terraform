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

    # Build decoded secrets JSON (excluding service account tokens)
    DECODED_JSON=$(kubectl get secrets -n "$NS" -o json | jq '
      .items
      | map(select(.type != "kubernetes.io/service-account-token"))
      | map({
          name: .metadata.name,
          type: .type,
          data: (.data | map_values(@base64d))
        })
    ')

    # Save locally
    echo "$DECODED_JSON" | jq . > "$OUTPUT_DIR/$NS/secrets.json"
    echo "Saved to $OUTPUT_DIR/$NS/secrets.json"

    # AWS secret name (customize prefix if desired)
    AWS_SECRET_NAME="k8s/${ENVIRONMENT}/${NS}/secrets"

    # Create or update AWS secret
    if aws secretsmanager describe-secret \
        --region "$AWS_REGION" \
        --secret-id "$AWS_SECRET_NAME" >/dev/null 2>&1; then

        echo "Updating AWS secret: $AWS_SECRET_NAME"
        aws secretsmanager put-secret-value \
            --region "$AWS_REGION" \
            --secret-id "$AWS_SECRET_NAME" \
            --secret-string "$DECODED_JSON" >/dev/null
    else
        echo "Creating AWS secret: $AWS_SECRET_NAME"
        aws secretsmanager create-secret \
            --region "$AWS_REGION" \
            --name "$AWS_SECRET_NAME" \
            --secret-string "$DECODED_JSON" >/dev/null
    fi

    echo "Namespace $NS synced to AWS."
    echo "-----------------------------------"
done

echo "All namespaces exported and pushed."
