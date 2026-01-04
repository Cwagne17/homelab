module "talos" {
  source = "../../modules/talos_cluster"

  providers = {
    proxmox = {
        name         = "abel"
        cluster_name = "homelab"
        endpoint     = "https://192.168.1.62:8006"
        insecure     = true
        username     = "root"
    }
  }

  image = {
    version        = "v1.10.3"
    update_version = "v1.12.0" # renovate: github-releases=siderolabs/talos
    schematic_path = "talos/image/schematic.yaml"
    # Point this to a new schematic file to update the schematic
    # update_schematic_path = "talos/image/schematic.yaml"
    }
  
  cluster = {
  name = "talos"
  # Only use a VIP if the nodes share a layer 2 network
  # Ref: https://www.talos.dev/v1.9/talos-guides/network/vip/#requirements
  vip     = "192.168.1.99"
  gateway = "192.168.1.1"
  # The version of talos features to use in generated machine configuration. Generally the same as image version.
  # See https://github.com/siderolabs/terraform-provider-talos/blob/main/docs/data-sources/machine_configuration.md
  # Uncomment to use this instead of version from talos_image.
  # talos_machine_config_version = "v1.9.2"
  proxmox_cluster    = "homelab"
  kubernetes_version = "v1.35.0" # renovate: github-releases=kubernetes/kubernetes
  cilium = {
    bootstrap_manifest_path = "talos/inline-manifests/cilium-install.yaml"
    values_file_path        = "../../k8s/infra/network/cilium/values.yaml"
  }
  gateway_api_version = "v1.4.1" # renovate: github-releases=kubernetes-sigs/gateway-api
  extra_manifests     = []
  kubelet             = <<-EOT
    extraArgs:
      # Needed for Netbird agent https://kubernetes.io/docs/tasks/administer-cluster/sysctl-cluster/#enabling-unsafe-sysctls
      allowed-unsafe-sysctls: net.ipv4.conf.all.src_valid_mark
  EOT
  api_server          = <<-EOT
    extraArgs:
      oidc-issuer-url: "https://authelia.stonegarden.dev"
      oidc-client-id: "kubectl"
      oidc-username-claim: "preferred_username"
      oidc-username-prefix: "authelia:"
      oidc-groups-claim: "groups"
      oidc-groups-prefix: "authelia:"
  EOT
}


  nodes   = {
  "ctrl-00" = {
    host_node     = "abel"
    machine_type  = "controlplane"
    ip            = "192.168.1.100"
    mac_address   = "BC:24:11:2E:C8:00"
    vm_id         = 800
    cpu           = 8
    ram_dedicated = 28672
    igpu          = true
  }
  "ctrl-01" = {
    host_node     = "euclid"
    machine_type  = "controlplane"
    ip            = "192.168.1.101"
    mac_address   = "BC:24:11:2E:C8:01"
    vm_id         = 801
    cpu           = 4
    ram_dedicated = 20480
    igpu          = true
    #update        = true
  }
  "ctrl-02" = {
    host_node     = "cantor"
    machine_type  = "controlplane"
    ip            = "192.168.1.102"
    mac_address   = "BC:24:11:2E:C8:02"
    vm_id         = 802
    cpu           = 4
    ram_dedicated = 6144
    #update        = true
  }
  "work-00" = {
    host_node     = "abel"
    machine_type  = "worker"
    ip            = "192.168.1.110"
    dns           = ["1.1.1.1", "8.8.8.8"] # Optional Value.
    mac_address   = "BC:24:11:2E:A8:00"
    vm_id         = 810
    cpu           = 8
    ram_dedicated = 4096
  }
}
}