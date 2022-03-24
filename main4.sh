#!/bin/bash
#!/usr/bin/env bash

sed -i 's/#   StrictHostKeyChecking yes/    StrictHostKeyChecking no/' /etc/ssh/ssh_config
systemctl restart sshd

echo "Choose your choice: "
echo "1. Deploy the katonic platform"
echo "2. Remove the katonic platform"
echo "Enter the number:  "
read choice

if [[ "${choice}" == "1" ]]
then

RED="\e[31m"
GREEN="\e[32m"
Yellow="\e[33m"
Magenta="\e[35m"
BOLDGREEN="\e[1;${GREEN}m"
Bold_Magenta="\e[1;${Magenta}m"
ENDCOLOR="\e[0m"

Region="us-east-1"

echo -e "${GREEN}Checking Katonic VPC can create in US East(N.Virginia) us-east-1 region.........${ENDCOLOR}"

VPCs=$(aws ec2 describe-vpcs --vpc-ids | grep VpcId | grep -oh "vpc-\w*" | wc -l)
  if [[ "${VPCs}" -ge "5" ]]
  then
          RED="\e[31m"
          GREEN="\e[32m"
          Yellow="\e[33m"
          Magenta="\e[35m"
          BOLDGREEN="\e[1;${GREEN}m"
          Bold_Magenta="\e[1;${Magenta}m"
          ENDCOLOR="\e[0m"

          echo -e "${RED}No space to create katonic VPC's in us-east-1 region. You have already 5 VPC's in us-east-1 region ${ENDCOLOR}"
          echo -e "${RED}Choose the different region ${ENDCOLOR}"
          echo "1. US East(Ohio) us-east-2"
          echo "2. US West(N.California) us-west-1"
          echo "3. US West(Oregon) us-west-2"
          echo "4. Asia Pacific(Mumbai) ap-south-1"
          echo "5. Asia Pacific(Sydney) ap-southeast-2"
          read region_no
          if [[ "${region_no}" == 1 ]]
          then
                  region_name=us-east-2
                  echo -e "${RED}You select US East(Ohio) region ${ENDCOLOR}"
          elif [[ "${region_no}" == 2 ]]
          then
                  region_name=us-west-1
                  echo -e "${RED}You select US West(N.California) region ${ENDCOLOR}"
          elif [[ "${region_no}" == 3 ]]
          then
                  region_name=us-west-2
                  echo -e "${RED}You select US West(Oregon) region ${ENDCOLOR}"
          elif [[ "${region_no}" == 4 ]]
          then
                  region_name=ap-south-1
                  echo -e "${RED}You select Asia Pacific(Mumbai) region ${ENDCOLOR}"
          elif [[ "${region_no}" == 5 ]]
          then
                  region_name=ap-southeast-2
                  echo -e "${RED}You select Asia Pacific(Sydney) region ${ENDCOLOR}"
          else
                  echo -e "${RED}Please select correct number ${ENDCOLOR}"
          fi
          Region="$region_name"

    else
        echo -e "${RED}You have space in US East(N.Virginia) us-east-1 region to create Katonic VPC!!! ${ENDCOLOR}"
    fi


# Update me

VpcCIDR="10.10.0.0/21"
PublicSubnets="10.10.0.0/24,10.10.1.0/24,10.10.2.0/24"
SSHKey="katonic-vpc"
StackName="katonic-vpc"
Bucket="katonic-deployment-update"
EnableVPCPeering="false"
EnvType="dev"


# EKS
StackNameEKS="katonic-cluster-eks"
#Region="us-east-1"
EksCluster="$StackNameEKS"
VpcName="katonic-vpc"

EksClusterStack="eksctl-katonic-cluster-eks-cluster"
EksClusterNodegroupStack="eksctl-katonic-cluster-eks-nodegroup-worker"

eks_version="1.21"
nodegroup_name="worker"
node_type="t2.xlarge"
deploy_nodes="3"
deploy_nodes_min="2"
deploy_nodes_max="4"
node_volume_size="50"


export AWS_DEFAULT_REGION=${Region}

echo -ne "${GREEN}Please enter your correct email id:  ${ENDCOLOR}"
read DEFAULT_USER_EMAIL

echo -e "${GREEN}Your email id is:  $DEFAULT_USER_EMAIL ${ENDCOLOR}"

echo -e "${GREEN}SNS topic creating.........${ENDCOLOR}"
aws sns create-topic --name my-topic

echo -e "${GREEN}Setting variable with sns arn.........${ENDCOLOR}"
sns_topic_arn=`aws sns list-topics | grep my-topic -w | sed 's/TopicArn//g'| cut -c 17- | tr -d '"'`
echo $sns_topic_arn

echo -e "${RED}Email confirmation mail send to your Email ID. Please confirm it.${ENDCOLOR}"
aws sns subscribe --topic-arn "$sns_topic_arn" --protocol email --notification-endpoint "$DEFAULT_USER_EMAIL"
for i in {1..10}
do
echo -e "${GREEN}Checking confirmation.........${ENDCOLOR}"
array=`aws sns list-subscriptions-by-topic --topic-arn "$sns_topic_arn" --query "Subscriptions[?SubscriptionArn=='PendingConfirmation']"`
if [[ $array == "[]" ]]
then
aws sns publish --topic-arn "$sns_topic_arn" --message "Welcome to Katonic!!!"

#Set the environment variable
sudo echo "export Env_email_var=$DEFAULT_USER_EMAIL">>~/.bashrc
sudo echo Env_email_var=$DEFAULT_USER_EMAIL>>~/.profile
sudo echo Env_email_var=$DEFAULT_USER_EMAIL>>/etc/environment
. ~/.bashrc
. ~/.profile
source ~/.bashrc
source ~/.profile

#Just for checking
# echo "System env var"
# echo $Env_email_var

# Fix
YAML="vpc.yaml"
Name="$StackName"

echo '
---
AWSTemplateFormatVersion: '2010-09-09'
Description: Basic VPC
Mappings:
  ARNNamespace:
    us-east-1:
      Partition: aws
    us-east-2:
      Partition: aws
    us-west-2:
      Partition: aws
    us-west-1:
      Partition: aws
    us-east-1:
      Partition: aws
    eu-central-1:
      Partition: aws
    ap-southeast-1:
      Partition: aws
    ap-northeast-1:
      Partition: aws
    ap-southeast-2:
      Partition: aws
    sa-east-1:
      Partition: aws
    us-gov-west-1:
      Partition: aws-us-gov
  S3Region:
    us-east-1:
      Region: us-east-1
    us-east-2:
      Region: us-east-2
    us-west-2:
      Region: us-east-1
    us-west-1:
      Region: us-east-1
    us-east-1:
      Region: us-east-1
    eu-central-1:
      Region: us-east-1
    ap-southeast-1:
      Region: us-east-1
    ap-northeast-1:
      Region: us-east-1
    ap-southeast-2:
      Region: us-east-1
    sa-east-1:
      Region: us-east-1
    us-gov-west-1:
      Region: us-gov-west-1
Parameters:
  Name:
    Type: String
    Description: Name references build template for automation
  Region:
    Type: String
  Bucket:
    Type: String
    Default: cloudgeeksca-deployment
  DeployBucketPrefix:
    Type: String
    Default: ""
  EnableVPCPeering:
    Type: String
    Default: false
    AllowedValues: ['false', 'true']
  VpcCIDR:
    Type: String
    Default: 10.10.0.0/21
  PublicSubnets:
    Type: CommaDelimitedList
    Description: List of 3 subnets
    Default: 10.10.0.0/24,10.10.1.0/24,10.10.2.0/24
  EnvType:
    Type: String
  SSHKey:
    Type: AWS::EC2::KeyPair::KeyName
    Default: devops
Conditions:
  CreatePeer: !Equals [ !Ref EnableVPCPeering, true]
Resources:
  Vpc:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: !Ref VpcCIDR
      EnableDnsSupport: 'true'
      EnableDnsHostnames: 'true'
      Tags:
        - Key: Name
          Value:
            Ref: AWS::StackName
        - Key: kubernetes.io/role/elb
          Value: shared
        - Key: alpha.eksctl.io/cluster-name
          Value: !Sub "${AWS::StackName}"
        - Key: eksctl.cluster.k8s.io/v1alpha1/cluster-name
          Value: !Sub "${AWS::StackName}"

  InternetGateway:
    Type: AWS::EC2::InternetGateway

  AttachGateway:
    Type: AWS::EC2::VPCGatewayAttachment
    Properties:
      VpcId:
        Ref: Vpc
      InternetGatewayId:
        Ref: InternetGateway

  PubSubnetAz1:
    Type: AWS::EC2::Subnet
    Properties:
      MapPublicIpOnLaunch: true
      VpcId:
        Ref: Vpc
      CidrBlock: !Select [0, !Ref PublicSubnets]
      AvailabilityZone:
        Fn::Select:
          - '0'
          - Fn::GetAZs:
              Ref: AWS::Region
      Tags:
        - Key: Name
          Value: !Sub ${AWS::StackName} Public Subnet (AZ1)
        - Key: alpha.eksctl.io/cluster-name
          Value: !Sub "${AWS::StackName}"
        - Key: eksctl.cluster.k8s.io/v1alpha1/cluster-name
          Value: !Sub "${AWS::StackName}"
        - Key: kubernetes.io/role/elb
          Value: 1
        - Key: Public-Subnet-AZ1
          Value: !Sub ${AWS::StackName}-Public-Subnet-AZ1


  PubSubnetAz2:
    Type: AWS::EC2::Subnet
    Properties:
      MapPublicIpOnLaunch: true
      VpcId:
        Ref: Vpc
      CidrBlock: !Select [1, !Ref PublicSubnets]
      AvailabilityZone:
        Fn::Select:
          - '1'
          - Fn::GetAZs:
              Ref: AWS::Region
      Tags:
        - Key: Name
          Value: !Sub ${AWS::StackName} Public Subnet (AZ2)
        - Key: alpha.eksctl.io/cluster-name
          Value: !Sub "${AWS::StackName}"
        - Key: eksctl.cluster.k8s.io/v1alpha1/cluster-name
          Value: !Sub "${AWS::StackName}"
        - Key: kubernetes.io/role/elb
          Value: 1
        - Key: Public-Subnet-AZ2
          Value: !Sub ${AWS::StackName}-Public-Subnet-AZ2

  PubSubnetAz3:
    Type: AWS::EC2::Subnet
    Properties:
      MapPublicIpOnLaunch: true
      VpcId:
        Ref: Vpc
      CidrBlock: !Select [2, !Ref PublicSubnets]
      AvailabilityZone:
        Fn::Select:
          - '2'
          - Fn::GetAZs:
              Ref: AWS::Region
      Tags:
        - Key: Name
          Value: !Sub ${AWS::StackName} Public Subnet (AZ3)
        - Key: alpha.eksctl.io/cluster-name
          Value: !Sub "${AWS::StackName}"
        - Key: eksctl.cluster.k8s.io/v1alpha1/cluster-name
          Value: !Sub "${AWS::StackName}"
        - Key: kubernetes.io/role/elb
          Value: 1
        - Key: Public-Subnet-AZ3
          Value: !Sub ${AWS::StackName}-Public-Subnet-AZ3

  PublicRouteTable:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref Vpc
      Tags:
        - Key: Name
          Value: !Sub ${AWS::StackName} Public Routes
        - Key: alpha.eksctl.io/cluster-name
          Value: !Sub "${AWS::StackName}"
        - Key: eksctl.cluster.k8s.io/v1alpha1/cluster-name
          Value: !Sub "${AWS::StackName}"

  DefaultPublicRoute:
    Type: AWS::EC2::Route
    DependsOn: AttachGateway
    Properties:
      RouteTableId: !Ref PublicRouteTable
      DestinationCidrBlock: 0.0.0.0/0
      GatewayId: !Ref InternetGateway

  PublicSubnet1RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      RouteTableId: !Ref PublicRouteTable
      SubnetId: !Ref PubSubnetAz1

  PublicSubnet2RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      RouteTableId: !Ref PublicRouteTable
      SubnetId: !Ref PubSubnetAz2

  PublicSubnet3RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      RouteTableId: !Ref PublicRouteTable
      SubnetId: !Ref PubSubnetAz3

  NoIngressSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupName: "no-ingress-sg"
      GroupDescription: "Security group with no ingress rule"
      VpcId: !Ref Vpc

  VPCPeeringConnection:
    Type: 'AWS::EC2::VPCPeeringConnection'
    Condition: CreatePeer
    Properties:
      VpcId: !Ref Vpc
      PeerVpcId: vpc-283cac51
      PeerRegion: us-east-1
      Tags:
        - Key: Name
          Value: !Sub ${AWS::StackName} peer with Main_Production

Outputs:
  VpcID:
    Description: Created VPC ID
    Value:
      Ref: Vpc
    Export:
      Name: !Sub ${AWS::StackName}-VpcID
  PublicSubnetAz1:
    Description: Public Subnet AZ1 created in VPC
    Value:
      Ref: PubSubnetAz1
  PublicSubnetAz2:
    Description: Public Subnet AZ2 created in VPC
    Value:
      Ref: PubSubnetAz2
  PublicSubnetAz3:
    Description: Public Subnet AZ2 created in VPC
    Value:
      Ref: PubSubnetAz3
  PublicSubnetGroup:
    Value: !Sub ${PubSubnetAz1},${PubSubnetAz2},${PubSubnetAz3}
    Export:
      Name: !Sub ${AWS::StackName}-PublicSubnetGroup
  VpcCidr:
    Description: VPC network block
    Value: !Ref VpcCIDR
    Export:
      Name: !Sub ${AWS::StackName}-VpcCidr
  StackName:
    Description: Output Stack Name
    Value: !Ref AWS::StackName
  Region:
    Description: Stack location
    Value: !Ref AWS::Region
 ' > $YAML


 # Parameters

 cat << EOF > parameters.json
 [
  {
    "ParameterKey": "Bucket",
    "ParameterValue": "$Bucket"
    },
   {
     "ParameterKey": "EnableVPCPeering",
     "ParameterValue": "$EnableVPCPeering"
    },
    {
      "ParameterKey": "EnvType",
      "ParameterValue": "$EnvType"
    },
    {
    "ParameterKey": "PublicSubnets",
    "ParameterValue": "$PublicSubnets"
    },
    {
    "ParameterKey": "Region",
    "ParameterValue": "$Region"
    },
    {
    "ParameterKey": "SSHKey",
    "ParameterValue": "$SSHKey"
    },
    {
    "ParameterKey": "VpcCIDR",
    "ParameterValue": "$VpcCIDR"
    },
    {
     "ParameterKey": "Name",
    "ParameterValue": "$Name"
    }


]
EOF

# Creating a key pair for EC2 Workers Nodes

mkdir ~/.ssh 2>&1 >/dev/null

aws ec2 create-key-pair --key-name $SSHKey --query 'KeyMaterial' --output text > ~/.ssh/$SSHKey.pem


# Create VPC Stack via Cloudformation
aws cloudformation create-stack --stack-name ${StackName} --template-body file://${YAML} --parameters file://parameters.json

echo -e "${GREEN}Katonic VPC is creating (takes 5 min to create).........${ENDCOLOR}"
sleep 4m


export Region
export AWS_DEFAULT_REGION=${Region}

PubSubnetAz1=`aws ec2 describe-subnets --region "${Region}" --filters Name=tag:Public-Subnet-AZ1,Values="${VpcName}-Public-Subnet-AZ1" | grep SubnetId | awk -F '"' '{print $4}'`
PubSubnetAz2=`aws ec2 describe-subnets --region "${Region}" --filters Name=tag:Public-Subnet-AZ1,Values="${VpcName}-Public-Subnet-AZ1" | grep SubnetId | awk -F '"' '{print $4}'`
PubSubnetAz3=`aws ec2 describe-subnets --region "${Region}" --filters Name=tag:Public-Subnet-AZ3,Values="${VpcName}-Public-Subnet-AZ3" | grep SubnetId | awk -F '"' '{print $4}'`

KEY_NAME="katonic_eks"

# Creating a key pair for EC2 Workers Nodes

mkdir ~/.ssh 2>&1 >/dev/null

aws ec2 create-key-pair --key-name $KEY_NAME --query 'KeyMaterial' --output text > ~/.ssh/$KEY_NAME.pem

export AWS_DEFAULT_REGION=${Region}


#Kubectl and eksctl installation
# Kubectl Installation
echo -e "${GREEN}Installing kubectl.........${ENDCOLOR}"
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl

chmod +x ./kubectl
sudo cp ./kubectl /usr/bin/kubectl
sudo mv ./kubectl /usr/local/bin/kubectl


# EKSCTL Installation
echo -e "${GREEN}Installing eksctl.........${ENDCOLOR}"
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/bin/eksctl
eksctl version

# Eks Cluster SetUp
echo -e "${GREEN}Creating EKS cluster(it takes 20 min to create cluster).........${ENDCOLOR}"

eksctl create cluster \
  --name ${EksCluster} \
  --version ${eks_version} \
  --vpc-public-subnets=$PubSubnetAz1,$PubSubnetAz2,$PubSubnetAz3 \
  --region ${Region} \
  --nodegroup-name ${nodegroup_name} \
  --node-type ${node_type} \
  --nodes ${deploy_nodes} \
  --nodes-min ${deploy_nodes_min} \
  --nodes-max ${deploy_nodes_max} \
  --ssh-access \
  --node-volume-size ${node_volume_size} \
  --ssh-public-key ${KEY_NAME} \
  --appmesh-access \
  --full-ecr-access \
  --alb-ingress-access \
  --managed \
  --asg-access \
  --verbose 3

echo -e "${GREEN}Your katonic eks cluster is ready to deploy katonic platform on it!!!${ENDCOLOR}"
echo -e "${Yellow}Wait for 1 min${ENDCOLOR}"
sleep 1m

echo "Ubuntu........."
sudo apt update -y
sudo apt install -y python3 python3-pip
sudo apt install ansible -y
sudo apt install -y python3 python3-pip
pip install --ignore-installed pyyaml
sudo ansible --version


cat > /etc/ansible/hosts << 'EOF'
[all]
localhost
EOF

#ssh-keygen and copy id to localhost
echo "Creating SSH keygen and ssh-copy-id "
ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa <<< y
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod og-wx ~/.ssh/authorized_keys

#Installing Ansible dependencies
echo -e "${GREEN}Deploying some ansible dependencies......... ${ENDCOLOR}"
ansible-galaxy collection install community.general
ansible-galaxy collection install kubernetes.core
ansible-galaxy collection install cloud.common

echo -e "${Yellow}Wait for 1 min${ENDCOLOR}"
sleep 1m
#Run the playbook to deploy the platform
echo -e "${GREEN}Now platform is deploying......... ${ENDCOLOR}"
ansible-playbook -b /root/deploy.yaml


#Sending username and password
dns_external_ip=`kubectl get svc istio-ingressgateway -n istio-system | awk '{print $4}' | tail -n +2`
echo "Your DNS address: " dns_external_ip
aws sns publish --topic-arn "$sns_topic_arn" --message "Domain name: $dns_external_ip  Username: $DEFAULT_USER_EMAIL Password:Oe7MU4d9loYV7cV3uzWloQ=="
echo -e "${GREEN}Your Katonic platform deployed successfully and the Credentials have mailed ${ENDCOLOR}"
break

else
    echo -e "${Yellow}Waiting for confirmation after 1 min it will check again your confirmation ${ENDCOLOR}"
    sleep 60
fi
done

elif  [[ "${choice}" == "2" ]]
then
    RED="\e[31m"
    GREEN="\e[32m"
    BOLDGREEN="\e[1;${GREEN}m"
    Yellow="\e[33m"
    ENDCOLOR="\e[0m"

    echo -e "${GREEN}Setting variable with sns arn ${ENDCOLOR}"
    sns_topic_arn=(`aws sns list-topics | grep my-topic -w | sed 's/TopicArn//g'| cut -c 17- | tr -d '"'`)
    echo $sns_topic_arn

    KEY_NAME="katonic_eks"
    SSHKey="katonic-vpc"
    StackName="katonic-vpc"
    EksClusterStack="eksctl-katonic-cluster-eks-cluster"
    EksClusterNodegroupStack="eksctl-katonic-cluster-eks-nodegroup-worker"

    #istioctl x uninstall --purge
    echo -e "${RED}Deleting sns topic ${ENDCOLOR}"
    aws sns delete-topic --topic-arn $sns_topic_arn
    echo -e "${RED}Deleting keypairs ${ENDCOLOR}"
    aws ec2 delete-key-pair --key-name katonic-vpc
    aws ec2 delete-key-pair --key-name katonic_eks
    echo -e "${RED}Deleting istio services......... ${ENDCOLOR}"
    kubectl delete svc istio-ingressgateway -n istio-system
    echo -e "${Yellow}Wait for 3 min${ENDCOLOR}"
    sleep 3m
    echo -e "${RED}eks cluster nodegroup stack deleting(it takes some time)......... ${ENDCOLOR}"
    aws cloudformation delete-stack --stack-name ${EksClusterNodegroupStack} --region us-east-1
    echo -e "${Yellow}Deleting Wait for 10 min${ENDCOLOR}"
    sleep 2m
    echo -e "${Yellow}Deleting....Please Wait${ENDCOLOR}"
    sleep 2m
    echo -e "${Yellow}Deleting....Please Wait${ENDCOLOR}"
    sleep 2m
    echo -e "${Yellow}Deleting....Please Wait${ENDCOLOR}"
    sleep 2m
    echo -e "${Yellow}Deleting....Please Wait${ENDCOLOR}"
    sleep 2m
    echo -e "${RED}eks cluster stack deleting(it takes some time)......... ${ENDCOLOR}"
    aws cloudformation delete-stack --stack-name ${EksClusterStack} --region us-east-1
    echo -e "${Yellow}Wait for 5 min${ENDCOLOR}"
    sleep 3m
    echo -e "${Yellow}Deleting....Please Wait${ENDCOLOR}"
    sleep 2m
    echo -e "${RED}katonic vpc deleting(it takes some time)......... ${ENDCOLOR}"
    aws cloudformation delete-stack --stack-name ${StackName} --region us-east-1
    echo -e "${Yellow}Wait for 3 min${ENDCOLOR}"
    sleep 3m
    echo -e "${RED}Removing all set environment variable ${ENDCOLOR}"
    unset Env_email_var
    sed -i '/Env_email_var/d' ~/.bashrc
    sed -i '/Env_email_var/d' ~/.profile
    sed -i '/Env_email_var/d' /etc/environment
    echo -e "${RED}Removing all files ${ENDCOLOR}"
    rm vpc.yaml
    rm deploy.yaml
    rm parameters.json
    echo -e "${GREEN}Succesfully remove all!!! ${ENDCOLOR}"
else
    echo -e "${RED}Not able to deploy katonic platform ${ENDCOLOR}"
fi
