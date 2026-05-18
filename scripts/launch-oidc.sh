#!/bin/bash
set -e

# ─────────────────────────────────────────
#  CONFIG — edit these before running
# ─────────────────────────────────────────
AWS_REGION="us-east-1"
AZ="us-east-1a"
INSTANCE_TYPE="t3.medium"
INSTANCE_NAME="prod-server"
KEY_NAME="prod-key"
SG_NAME="prod-server-sg"
VOLUME_SIZE=20
AMI_OWNER="055394704281"

# Set this to use a specific AMI, or leave empty to auto-pick latest
AMI_ID=""
# ─────────────────────────────────────────

echo ""
echo "=========================================="
echo "  EC2 Launch from AMI"
echo "=========================================="
echo ""

# ── 1. Resolve AMI ID ─────────────────────
echo "[1/6] Resolving AMI..."

if [ -z "$AMI_ID" ]; then
  AMI_ID=$(aws ec2 describe-images \
    --region $AWS_REGION \
    --owners $AMI_OWNER \
    --filters "Name=name,Values=prod-lightsail-*" \
    --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
    --output text)
  echo "  Using latest AMI: $AMI_ID"
else
  echo "  Using specified AMI: $AMI_ID"
fi

if [ "$AMI_ID" == "None" ] || [ -z "$AMI_ID" ]; then
  echo "  ❌ No AMI found. Run the GitHub Actions build first."
  exit 1
fi

# ── 2. Get VPC and Subnet ─────────────────
echo ""
echo "[2/6] Getting VPC and subnet..."

VPC_ID=$(aws ec2 describe-vpcs \
  --region $AWS_REGION \
  --filters "Name=isDefault,Values=true" \
  --query 'Vpcs[0].VpcId' \
  --output text)

SUBNET_ID=$(aws ec2 describe-subnets \
  --region $AWS_REGION \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=availabilityZone,Values=$AZ" \
  --query 'Subnets[0].SubnetId' \
  --output text)

echo "  VPC:    $VPC_ID"
echo "  Subnet: $SUBNET_ID"

# ── 3. Security Group ─────────────────────
echo ""
echo "[3/6] Setting up security group..."

SG_ID=$(aws ec2 describe-security-groups \
  --region $AWS_REGION \
  --filters "Name=group-name,Values=$SG_NAME" "Name=vpc-id,Values=$VPC_ID" \
  --query 'SecurityGroups[0].GroupId' \
  --output text 2>/dev/null || echo "")

if [ -z "$SG_ID" ] || [ "$SG_ID" == "None" ]; then
  SG_ID=$(aws ec2 create-security-group \
    --region $AWS_REGION \
    --group-name $SG_NAME \
    --description "Prod server security group" \
    --vpc-id $VPC_ID \
    --query 'GroupId' \
    --output text)

  aws ec2 authorize-security-group-ingress --region $AWS_REGION --group-id $SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0
  aws ec2 authorize-security-group-ingress --region $AWS_REGION --group-id $SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0
  aws ec2 authorize-security-group-ingress --region $AWS_REGION --group-id $SG_ID --protocol tcp --port 443 --cidr 0.0.0.0/0
  echo "  Created SG: $SG_ID"
else
  echo "  Using existing SG: $SG_ID"
fi

# ── 4. Key Pair ───────────────────────────
echo ""
echo "[4/6] Setting up key pair..."

EXISTING_KEY=$(aws ec2 describe-key-pairs \
  --region $AWS_REGION \
  --key-names $KEY_NAME \
  --query 'KeyPairs[0].KeyName' \
  --output text 2>/dev/null || echo "")

if [ -z "$EXISTING_KEY" ] || [ "$EXISTING_KEY" == "None" ]; then
  aws ec2 create-key-pair \
    --region $AWS_REGION \
    --key-name $KEY_NAME \
    --query 'KeyMaterial' \
    --output text > ${KEY_NAME}.pem
  chmod 400 ${KEY_NAME}.pem
  echo "  Created key: ${KEY_NAME}.pem"
  echo ""
  echo "  ⚠️  SAVE THIS KEY — copy it now:"
  echo "──────────────────────────────────────"
  cat ${KEY_NAME}.pem
  echo ""
  echo "──────────────────────────────────────"
else
  echo "  Key pair already exists — skipping."
fi

# ── 5. Launch Instance ────────────────────
echo ""
echo "[5/6] Launching EC2 instance..."

EXISTING_INSTANCE=$(aws ec2 describe-instances \
  --region $AWS_REGION \
  --filters "Name=tag:Name,Values=$INSTANCE_NAME" "Name=instance-state-name,Values=running,pending,stopped" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text 2>/dev/null || echo "")

if [ -n "$EXISTING_INSTANCE" ] && [ "$EXISTING_INSTANCE" != "None" ]; then
  INSTANCE_ID=$EXISTING_INSTANCE
  echo "  Instance already exists: $INSTANCE_ID"
else
  INSTANCE_ID=$(aws ec2 run-instances \
    --region $AWS_REGION \
    --image-id $AMI_ID \
    --instance-type $INSTANCE_TYPE \
    --subnet-id $SUBNET_ID \
    --security-group-ids $SG_ID \
    --key-name $KEY_NAME \
    --associate-public-ip-address \
    --block-device-mappings "[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":$VOLUME_SIZE,\"VolumeType\":\"gp3\"}}]" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
    --query 'Instances[0].InstanceId' \
    --output text)
  echo "  Launched: $INSTANCE_ID"
fi

# Wait for running
echo "  Waiting for instance to be running..."
aws ec2 wait instance-running --region $AWS_REGION --instance-ids $INSTANCE_ID
echo "  Instance is running."

# ── 6. Elastic IP ─────────────────────────
echo ""
echo "[6/6] Attaching Elastic IP..."

EXISTING_EIP=$(aws ec2 describe-addresses \
  --region $AWS_REGION \
  --filters "Name=instance-id,Values=$INSTANCE_ID" \
  --query 'Addresses[0].PublicIp' \
  --output text 2>/dev/null || echo "")

if [ -n "$EXISTING_EIP" ] && [ "$EXISTING_EIP" != "None" ]; then
  PUBLIC_IP=$EXISTING_EIP
  echo "  Elastic IP already attached: $PUBLIC_IP"
else
  ALLOC_ID=$(aws ec2 allocate-address --region $AWS_REGION --query 'AllocationId' --output text)
  aws ec2 associate-address --region $AWS_REGION --instance-id $INSTANCE_ID --allocation-id $ALLOC_ID > /dev/null
  PUBLIC_IP=$(aws ec2 describe-addresses \
    --region $AWS_REGION \
    --allocation-ids $ALLOC_ID \
    --query 'Addresses[0].PublicIp' \
    --output text)
  echo "  Elastic IP: $PUBLIC_IP"
fi

# ── Done ──────────────────────────────────
echo ""
echo "=========================================="
echo "  ✅ Server is ready!"
echo "=========================================="
echo ""
echo "  AMI ID      : $AMI_ID"
echo "  Instance ID : $INSTANCE_ID"
echo "  Public IP   : $PUBLIC_IP"
echo ""
echo "  SSH command:"
echo "  ssh -i ${KEY_NAME}.pem ubuntu@${PUBLIC_IP}"
echo "=========================================="
