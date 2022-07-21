# Terraform Azure VM with Pub IP

A working example of Terraform + Ansible provisioning. Useful when deploying VM with Ansible
playbook

This Terraform script requires your Ansible files at the same root level as your Terraform folder
like the following:

```
  ansible/
    play.focal.yml
    roles/
  terraform/
    main.tf
```

## Setup
To start, please ensure you're logged into Azure using  `az` cli tool
```
  az login
```

And make sure you've set your active session to the right subscription correctly
```
  az account set --subscription {subscription_id}
```

