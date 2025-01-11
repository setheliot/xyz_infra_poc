

#
# Give EKS nodes necessary permissions to run the LBC
resource "aws_iam_policy" "alb_controller_custom" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  description = "IAM policy for AWS Load Balancer Controller"
  policy      = file("${path.module}/policies/iam_policy.json") # Path to your downloaded file
}

resource "aws_iam_role_policy_attachment" "alb_policy_node" {
  policy_arn = aws_iam_policy.alb_controller_custom.arn
  role       = data.terraform_remote_state.infra.outputs.eks_node_iam_role_name
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