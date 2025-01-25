#
# AWS Load Balancer Controller

# Retrieve the LBC IAM policy
# This should have already been created once per account by the iam modules
# If it does not exist, will fail with timeout after 2 minutes
data "aws_iam_policy" "lbc_policy" {
  name = "AWSLoadBalancerControllerIAMPolicy"
}

# Attach the policy (existing or newly created) to the node IAM role
resource "aws_iam_role_policy_attachment" "alb_policy_node" {
  policy_arn = data.aws_iam_policy.lbc_policy.arn
  role       = local.eks_node_iam_role_name
}

#
# Create the K8s Service Account that will be used by Helm
resource "kubernetes_service_account" "alb_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
  }
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"

  set {
    name  = "clusterName"
    value = local.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.alb_controller.metadata[0].name
  }

  set {
    name  = "region"
    value = local.region
  }

  set {
    name  = "vpcId"
    value = local.vpc_id
  }
}


#
# EBS Persistent volume
# (This creates the PVC - the volume gets created when the pod attempts to mount it)

# Retrieve the CSI driver  policy
data "aws_iam_policy" "csi_policy" {
  name = "AmazonEBSCSIDriverPolicy"
}

# Attach the policy to the cluster IAM role
resource "aws_iam_role_policy_attachment" "csi_policy_attachment" {
  policy_arn = data.aws_iam_policy.csi_policy.arn
  role       = local.eks_node_iam_role_name
}

resource "kubernetes_storage_class" "ebs" {
  metadata {
    name = "ebs-storage-class"
  }

  storage_provisioner = "ebs.csi.aws.com"
  reclaim_policy      = "Retain"
  volume_binding_mode = "WaitForFirstConsumer"
  parameters = {
    type   = "gp3"
    fsType = "ext4"
  }
}

resource "kubernetes_persistent_volume_claim_v1" "ebs_pvc" {
  metadata {
    name = "ebs-volume-claim"
  }

  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = "1Gi"
      }
    }

    storage_class_name = "ebs-storage-class"
  }
  wait_until_bound = false
}