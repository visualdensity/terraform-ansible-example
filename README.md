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
