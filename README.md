# Автор: Лоцман Сергей Михайлович DEVOPS-35

# Дипломный практикум в Yandex.Cloud
  * [Цели:](#цели)
  * [Этапы выполнения:](#этапы-выполнения)
     * [Создание облачной инфраструктуры](#создание-облачной-инфраструктуры)
     * [Создание Kubernetes кластера](#создание-kubernetes-кластера)
     * [Создание тестового приложения](#создание-тестового-приложения)
     * [Подготовка cистемы мониторинга и деплой приложения](#подготовка-cистемы-мониторинга-и-деплой-приложения)
     * [Установка и настройка CI/CD](#установка-и-настройка-cicd)
  * [Что необходимо для сдачи задания?](#что-необходимо-для-сдачи-задания)
  * [Как правильно задавать вопросы дипломному руководителю?](#как-правильно-задавать-вопросы-дипломному-руководителю)

**Перед началом работы над дипломным заданием изучите [Инструкция по экономии облачных ресурсов](https://github.com/netology-code/devops-materials/blob/master/cloudwork.MD).**

---
## Цели:

1. Подготовить облачную инфраструктуру на базе облачного провайдера Яндекс.Облако.
2. Запустить и сконфигурировать Kubernetes кластер.
3. Установить и настроить систему мониторинга.
4. Настроить и автоматизировать сборку тестового приложения с использованием Docker-контейнеров.
5. Настроить CI для автоматической сборки и тестирования.
6. Настроить CD для автоматического развёртывания приложения.

---
## Этапы выполнения:


### Создание облачной инфраструктуры

Для начала необходимо подготовить облачную инфраструктуру в ЯО при помощи [Terraform](https://www.terraform.io/).

Особенности выполнения:

- Бюджет купона ограничен, что следует иметь в виду при проектировании инфраструктуры и использовании ресурсов;
Для облачного k8s используйте региональный мастер(неотказоустойчивый). Для self-hosted k8s минимизируйте ресурсы ВМ и долю ЦПУ. В обоих вариантах используйте прерываемые ВМ для worker nodes.

Предварительная подготовка к установке и запуску Kubernetes кластера.

1. Создайте сервисный аккаунт, который будет в дальнейшем использоваться Terraform для работы с инфраструктурой с необходимыми и достаточными правами. Не стоит использовать права суперпользователя
2. Подготовьте [backend](https://www.terraform.io/docs/language/settings/backends/index.html) для Terraform:  
   а. Рекомендуемый вариант: S3 bucket в созданном ЯО аккаунте(создание бакета через TF)
   б. Альтернативный вариант:  [Terraform Cloud](https://app.terraform.io/)  
3. Создайте VPC с подсетями в разных зонах доступности.
4. Убедитесь, что теперь вы можете выполнить команды `terraform destroy` и `terraform apply` без дополнительных ручных действий.
5. В случае использования [Terraform Cloud](https://app.terraform.io/) в качестве [backend](https://www.terraform.io/docs/language/settings/backends/index.html) убедитесь, что применение изменений успешно проходит, используя web-интерфейс Terraform cloud.

Ожидаемые результаты:

1. Terraform сконфигурирован и создание инфраструктуры посредством Terraform возможно без дополнительных ручных действий.
2. Полученная конфигурация инфраструктуры является предварительной, поэтому в ходе дальнейшего выполнения задания возможны изменения.

### Выполнение этапа "Создание облачной инфраструктуры":

1. Создам сервисный аккаунт с необходимыми правами для работы с облачной инфраструктурой:

```
# Создаем сервисный аккаунт для Terraform
resource "yandex_iam_service_account" "service" {
  folder_id = var.folder_id
  name      = var.account_name
}

# Выдаем роль editor сервисному аккаунту Terraform
resource "yandex_resourcemanager_folder_iam_member" "service_editor" {
  folder_id = var.folder_id
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.service.id}"
}
```

2. Подготавливаю backend для Terraform. Использовать буду S3-bucket:

```
# Создаем статический ключ доступа для сервисного аккаунта
resource "yandex_iam_service_account_static_access_key" "terraform_service_account_key" {
  service_account_id = yandex_iam_service_account.service.id
}

# Используем ключ доступа для создания бакета
resource "yandex_storage_bucket" "tf-bucket" {
  bucket     = "lsm-diplom-bucket"
  max_size   = 1073741824
  access_key = yandex_iam_service_account_static_access_key.terraform_service_account_key.access_key
  secret_key = yandex_iam_service_account_static_access_key.terraform_service_account_key.secret_key

  anonymous_access_flags {
    read = false
    list = false
  }

  force_destroy = true

provisioner "local-exec" {
  command = "echo export ACCESS_KEY=${yandex_iam_service_account_static_access_key.terraform_service_account_key.access_key} > ../terraform/backend.tfvars"
}

provisioner "local-exec" {
  command = "echo export SECRET_KEY=${yandex_iam_service_account_static_access_key.terraform_service_account_key.secret_key} >> ../terraform/backend.tfvars"
}
}
```

Инициализирую проект:

```bash
╰─➤terraform init

Initializing the backend...

Initializing provider plugins...
- Finding latest version of yandex-cloud/yandex...
- Installing yandex-cloud/yandex v0.126.0...
- Installed yandex-cloud/yandex v0.126.0 (unauthenticated)

Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that Terraform can guarantee to make the same selections by default when
you run "terraform init" in the future.

╷
│ Warning: Incomplete lock file information for providers
│ 
│ Due to your customized provider installation methods, Terraform was forced to calculate lock file checksums locally for the following providers:
│   - yandex-cloud/yandex
│ 
│ The current .terraform.lock.hcl file only includes checksums for linux_amd64, so Terraform running on another platform will fail to install these providers.
│ 
│ To calculate additional checksums for another platform, run:
│   terraform providers lock -platform=linux_amd64
│ (where linux_amd64 is the platform to generate)
╵

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```

Применю код:

```bash
╰─➤terraform apply -auto-approve

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # yandex_iam_service_account.service will be created
  + resource "yandex_iam_service_account" "service" {
      + created_at = (known after apply)
      + folder_id  = "b1gl6dqee4o5qromajnb"
      + id         = (known after apply)
      + name       = "service"
    }

  # yandex_iam_service_account_static_access_key.terraform_service_account_key will be created
  + resource "yandex_iam_service_account_static_access_key" "terraform_service_account_key" {
      + access_key           = (known after apply)
      + created_at           = (known after apply)
      + encrypted_secret_key = (known after apply)
      + id                   = (known after apply)
      + key_fingerprint      = (known after apply)
      + secret_key           = (sensitive value)
      + service_account_id   = (known after apply)
    }

  # yandex_resourcemanager_folder_iam_member.service_editor will be created
  + resource "yandex_resourcemanager_folder_iam_member" "service_editor" {
      + folder_id = "b1gl6dqee4o5qromajnb"
      + id        = (known after apply)
      + member    = (known after apply)
      + role      = "editor"
    }

  # yandex_storage_bucket.tf-bucket will be created
  + resource "yandex_storage_bucket" "tf-bucket" {
      + access_key            = (known after apply)
      + bucket                = "lsm-diplom-bucket"
      + bucket_domain_name    = (known after apply)
      + default_storage_class = (known after apply)
      + folder_id             = (known after apply)
      + force_destroy         = true
      + id                    = (known after apply)
      + max_size              = 1073741824
      + secret_key            = (sensitive value)
      + website_domain        = (known after apply)
      + website_endpoint      = (known after apply)

      + anonymous_access_flags {
          + list = false
          + read = false
        }
    }

Plan: 4 to add, 0 to change, 0 to destroy.
yandex_iam_service_account.service: Creating...
yandex_iam_service_account.service: Creation complete after 3s [id=aje7cftietvodb39sfn9]
yandex_resourcemanager_folder_iam_member.service_editor: Creating...
yandex_iam_service_account_static_access_key.terraform_service_account_key: Creating...
yandex_iam_service_account_static_access_key.terraform_service_account_key: Creation complete after 2s [id=ajekmuv72g6k56r4kk47]
yandex_storage_bucket.tf-bucket: Creating...
yandex_resourcemanager_folder_iam_member.service_editor: Creation complete after 4s [id=b1gl6dqee4o5qromajnb/editor/serviceAccount:aje7cftietvodb39sfn9]
yandex_storage_bucket.tf-bucket: Provisioning with 'local-exec'...
yandex_storage_bucket.tf-bucket (local-exec): Executing: ["/bin/sh" "-c" "echo export AWS_ACCESS_KEY=YCAJEEzR7VH5QJ8PNDhFcsxuD > ../terraform/backend.tfvars"]
yandex_storage_bucket.tf-bucket: Provisioning with 'local-exec'...
yandex_storage_bucket.tf-bucket (local-exec): (output suppressed due to sensitive value in config)
yandex_storage_bucket.tf-bucket: Creation complete after 5s [id=lsm-diplom-bucket]

Apply complete! Resources: 4 added, 0 changed, 0 destroyed.
```

В результате применения этого кода Terraform был создан сервисный аккаунт с правами для редактирования, статический ключ доступа и S3-bucket. Переменные `AWS_ACCESS_KEY` и `AWS_SECRET_KEY` будут записаны в файл `backend.tfvars`. Сделано так потому, что эти данные являются очень чувствительными и не рекомендуется их хранить в облаке. Эти переменные будут в экспортированы в оболочку рабочего окружения.

Проверю, создался ли S3-bucket и сервисный аккаунт:

```bash
╰─➤yc iam service-account list
+----------------------+---------+--------+
|          ID          |  NAME   | LABELS |
+----------------------+---------+--------+
| aje7cftietvodb39sfn9 | service |        |
+----------------------+---------+--------+


╰─➤yc storage bucket list
+-------------------+----------------------+------------+-----------------------+---------------------+
|       NAME        |      FOLDER ID       |  MAX SIZE  | DEFAULT STORAGE CLASS |     CREATED AT      |
+-------------------+----------------------+------------+-----------------------+---------------------+
| lsm-diplom-bucket | b1gl6dqee4o5qromajnb | 1073741824 | STANDARD              | 2024-08-11 16:38:28 |
+-------------------+----------------------+------------+-----------------------+---------------------+
```

Сервисный аккаунт и S3-bucket созданы.

После создания S3-bucket, выполню настройку для его использования в качестве backend для Terraform. Для этого пишу следующий код:

```
terraform {
  backend "s3" {
    endpoint = "storage.yandexcloud.net"
    bucket = "lsm-diplom-bucket"
    region = "ru-central1"
    key = "lsm-diplom-bucket/terraform.tfstate"
    skip_region_validation = true
    skip_credentials_validation = true
  }
}
```
Этот код настраивает Terraform на использование Yandex Cloud Storage в качестве места для хранения файла состояния `terraform.tfstate`, который содержит информацию о конфигурации и состоянии управляемых Terraform ресурсов. Чтобы код был корректно применен и Terraform успешно инициализировался, задам параметры для доступа к S3 хранилищу. Как писал выше, делать это я буду с помощью переменных окружения:

```bash
╰─➤export AWS_SECRET_KEY=YCM_9O3E5WFT8j1EbrFmRRJ1v_ibezi56MSZu7ce

╰─➤export AWS_ACCESS_KEY=YCAJEEzR7VH5QJ8PNDhFcsxuD
```

3. Создаю VPC с подсетями в разных зонах доступности:

```
resource "yandex_vpc_network" "diplom" {
  name = var.vpc_name
}
resource "yandex_vpc_subnet" "diplom-subnet1" {
  name           = var.subnet1
  zone           = var.zone1
  network_id     = yandex_vpc_network.diplom.id
  v4_cidr_blocks = var.cidr1
}

resource "yandex_vpc_subnet" "diplom-subnet2" {
  name           = var.subnet2
  zone           = var.zone2
  network_id     = yandex_vpc_network.diplom.id
  v4_cidr_blocks = var.cidr2
}

variable "zone1" {
  type        = string
  default     = "ru-central1-a"
  description = "https://cloud.yandex.ru/docs/overview/concepts/geo-scope"
}

variable "zone2" {
  type        = string
  default     = "ru-central1-b"
  description = "https://cloud.yandex.ru/docs/overview/concepts/geo-scope"
}

variable "cidr1" {
  type        = list(string)
  default     = ["10.0.1.0/24"]
  description = "https://cloud.yandex.ru/docs/vpc/operations/subnet-create"
}

variable "cidr2" {
  type        = list(string)
  default     = ["10.0.2.0/24"]
  description = "https://cloud.yandex.ru/docs/vpc/operations/subnet-create"
}

variable "vpc_name" {
  type        = string
  default     = "diplom"
  description = "VPC network&subnet name"
}

variable "bucket_name" {
  type        = string
  default     = "ft-state"
  description = "VPC network&subnet name"
}

variable "subnet1" {
  type        = string
  default     = "diplom-subnet1"
  description = "subnet name"
}

variable "subnet2" {
  type        = string
  default     = "diplom-subnet2"
  description = "subnet name"
}
```

4. Описываю код Terraform для создания виртуальных машин для Kubernetes кластера. Буду использовать одну Master ноду и две Worker ноды.

Инициализирую Terraform:

```bash
╰─➤terraform init

Initializing the backend...

Successfully configured the backend "s3"! Terraform will automatically
use this backend unless the backend configuration changes.

Initializing provider plugins...
- Finding latest version of hashicorp/template...
- Finding latest version of yandex-cloud/yandex...
- Finding latest version of hashicorp/local...
- Installing hashicorp/template v2.2.0...
- Installed hashicorp/template v2.2.0 (unauthenticated)
- Installing yandex-cloud/yandex v0.126.0...
- Installed yandex-cloud/yandex v0.126.0 (unauthenticated)
- Installing hashicorp/local v2.5.1...
- Installed hashicorp/local v2.5.1 (unauthenticated)

Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that Terraform can guarantee to make the same selections by default when
you run "terraform init" in the future.

╷
│ Warning: Incomplete lock file information for providers
│ 
│ Due to your customized provider installation methods, Terraform was forced to calculate lock file checksums locally for the following providers:
│   - hashicorp/local
│   - hashicorp/template
│   - yandex-cloud/yandex
│ 
│ The current .terraform.lock.hcl file only includes checksums for linux_amd64, so Terraform running on another platform will fail to install these providers.
│ 
│ To calculate additional checksums for another platform, run:
│   terraform providers lock -platform=linux_amd64
│ (where linux_amd64 is the platform to generate)
╵

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```

Видно, что Terraform успешно инициализирован, backend с типом s3 успешно настроен. Terraform будет использовать этот backend для хранения файла состояния `terraform.tfstate`.

Для проверки правильности кода, можно использовать команды `terraform validate` и `terraform plan`. В моём коде ошибок не обнаружено:

```bash
╰─➤terraform validate 
Success! The configuration is valid.
```

Применю код для создания облачной инфраструктуры, состоящей из одной Master ноды, двух Worker нод, сети и подсети:

```bash
╰─➤terraform apply -auto-approve
data.template_file.cloudinit: Reading...
data.template_file.cloudinit: Read complete after 0s [id=f95b9145823e7854baf57a6dcb4d770613300f5382900a7a1abd3831abed7c6b]
data.yandex_compute_image.ubuntu-master: Reading...
data.yandex_compute_image.ubuntu-worker: Reading...
data.yandex_compute_image.ubuntu-worker: Read complete after 0s [id=fd8ue2nph2v23d0rtfug]
data.yandex_compute_image.ubuntu-master: Read complete after 0s [id=fd8ue2nph2v23d0rtfug]

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # local_file.hosts_cfg_kubespray[0] will be created
  + resource "local_file" "hosts_cfg_kubespray" {
      + content              = (known after apply)
      + content_base64sha256 = (known after apply)
      + content_base64sha512 = (known after apply)
      + content_md5          = (known after apply)
      + content_sha1         = (known after apply)
      + content_sha256       = (known after apply)
      + content_sha512       = (known after apply)
      + directory_permission = "0777"
      + file_permission      = "0777"
      + filename             = "../../kubespray/inventory/mycluster/hosts.yaml"
      + id                   = (known after apply)
    }

  # yandex_compute_instance.master[0] will be created
  + resource "yandex_compute_instance" "master" {
      + allow_stopping_for_update = true
      + created_at                = (known after apply)
      + folder_id                 = (known after apply)
      + fqdn                      = (known after apply)
      + gpu_cluster_id            = (known after apply)
      + hostname                  = (known after apply)
      + id                        = (known after apply)
      + maintenance_grace_period  = (known after apply)
      + maintenance_policy        = (known after apply)
      + metadata                  = {
          + "serial-port-enable" = "1"
          + "ssh-keys"           = <<-EOT
                ubuntu:ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBl5/crtWIqG261tg/WA/bbDS3XWFJS8McPXaHDnrP6S LotsmanSM@mail.ru
            EOT
          + "user-data"          = <<-EOT
                #cloud-config
                users:
                  - name: ubuntu
                    groups: sudo
                    shell: /bin/bash
                    sudo: ['ALL=(ALL) NOPASSWD:ALL']
                    ssh_authorized_keys:
                      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBl5/crtWIqG261tg/WA/bbDS3XWFJS8McPXaHDnrP6S LotsmanSM@mail.ru
                
                package_update: true
                package_upgrade: false
                packages:
                  - mc
                  - git
                  - apt-transport-https
                  - ca-certificates
                  - curl
                  - gnupg
                  - lsb-release
                  - unattended-upgrades
                
                runcmd:
                  - curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
                  - chmod 700 get_helm.sh
                  - ./get_helm.sh
            EOT
        }
      + name                      = "master"
      + network_acceleration_type = "standard"
      + platform_id               = "standard-v1"
      + service_account_id        = (known after apply)
      + status                    = (known after apply)
      + zone                      = "ru-central1-a"

      + boot_disk {
          + auto_delete = true
          + device_name = (known after apply)
          + disk_id     = (known after apply)
          + mode        = (known after apply)

          + initialize_params {
              + block_size  = (known after apply)
              + description = (known after apply)
              + image_id    = "fd8ue2nph2v23d0rtfug"
              + name        = (known after apply)
              + size        = 10
              + snapshot_id = (known after apply)
              + type        = "network-hdd"
            }
        }

      + network_interface {
          + index              = (known after apply)
          + ip_address         = (known after apply)
          + ipv4               = true
          + ipv6               = (known after apply)
          + ipv6_address       = (known after apply)
          + mac_address        = (known after apply)
          + nat                = true
          + nat_ip_address     = (known after apply)
          + nat_ip_version     = (known after apply)
          + security_group_ids = (known after apply)
          + subnet_id          = (known after apply)
        }

      + resources {
          + core_fraction = 5
          + cores         = 2
          + memory        = 4
        }

      + scheduling_policy {
          + preemptible = true
        }
    }

  # yandex_compute_instance.worker[0] will be created
  + resource "yandex_compute_instance" "worker" {
      + allow_stopping_for_update = true
      + created_at                = (known after apply)
      + folder_id                 = (known after apply)
      + fqdn                      = (known after apply)
      + gpu_cluster_id            = (known after apply)
      + hostname                  = (known after apply)
      + id                        = (known after apply)
      + maintenance_grace_period  = (known after apply)
      + maintenance_policy        = (known after apply)
      + metadata                  = {
          + "serial-port-enable" = "1"
          + "ssh-keys"           = <<-EOT
                ubuntu:ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBl5/crtWIqG261tg/WA/bbDS3XWFJS8McPXaHDnrP6S LotsmanSM@mail.ru
            EOT
          + "user-data"          = <<-EOT
                #cloud-config
                users:
                  - name: ubuntu
                    groups: sudo
                    shell: /bin/bash
                    sudo: ['ALL=(ALL) NOPASSWD:ALL']
                    ssh_authorized_keys:
                      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBl5/crtWIqG261tg/WA/bbDS3XWFJS8McPXaHDnrP6S LotsmanSM@mail.ru
                
                package_update: true
                package_upgrade: false
                packages:
                  - mc
                  - git
                  - apt-transport-https
                  - ca-certificates
                  - curl
                  - gnupg
                  - lsb-release
                  - unattended-upgrades
                
                runcmd:
                  - curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
                  - chmod 700 get_helm.sh
                  - ./get_helm.sh
            EOT
        }
      + name                      = "worker-1"
      + network_acceleration_type = "standard"
      + platform_id               = "standard-v1"
      + service_account_id        = (known after apply)
      + status                    = (known after apply)
      + zone                      = "ru-central1-b"

      + boot_disk {
          + auto_delete = true
          + device_name = (known after apply)
          + disk_id     = (known after apply)
          + mode        = (known after apply)

          + initialize_params {
              + block_size  = (known after apply)
              + description = (known after apply)
              + image_id    = "fd8ue2nph2v23d0rtfug"
              + name        = (known after apply)
              + size        = 10
              + snapshot_id = (known after apply)
              + type        = "network-hdd"
            }
        }

      + network_interface {
          + index              = (known after apply)
          + ip_address         = (known after apply)
          + ipv4               = true
          + ipv6               = (known after apply)
          + ipv6_address       = (known after apply)
          + mac_address        = (known after apply)
          + nat                = true
          + nat_ip_address     = (known after apply)
          + nat_ip_version     = (known after apply)
          + security_group_ids = (known after apply)
          + subnet_id          = (known after apply)
        }

      + resources {
          + core_fraction = 100
          + cores         = 4
          + memory        = 8
        }

      + scheduling_policy {
          + preemptible = true
        }
    }

  # yandex_compute_instance.worker[1] will be created
  + resource "yandex_compute_instance" "worker" {
      + allow_stopping_for_update = true
      + created_at                = (known after apply)
      + folder_id                 = (known after apply)
      + fqdn                      = (known after apply)
      + gpu_cluster_id            = (known after apply)
      + hostname                  = (known after apply)
      + id                        = (known after apply)
      + maintenance_grace_period  = (known after apply)
      + maintenance_policy        = (known after apply)
      + metadata                  = {
          + "serial-port-enable" = "1"
          + "ssh-keys"           = <<-EOT
                ubuntu:ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBl5/crtWIqG261tg/WA/bbDS3XWFJS8McPXaHDnrP6S LotsmanSM@mail.ru
            EOT
          + "user-data"          = <<-EOT
                #cloud-config
                users:
                  - name: ubuntu
                    groups: sudo
                    shell: /bin/bash
                    sudo: ['ALL=(ALL) NOPASSWD:ALL']
                    ssh_authorized_keys:
                      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBl5/crtWIqG261tg/WA/bbDS3XWFJS8McPXaHDnrP6S LotsmanSM@mail.ru
                
                package_update: true
                package_upgrade: false
                packages:
                  - mc
                  - git
                  - apt-transport-https
                  - ca-certificates
                  - curl
                  - gnupg
                  - lsb-release
                  - unattended-upgrades
                
                runcmd:
                  - curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
                  - chmod 700 get_helm.sh
                  - ./get_helm.sh
            EOT
        }
      + name                      = "worker-2"
      + network_acceleration_type = "standard"
      + platform_id               = "standard-v1"
      + service_account_id        = (known after apply)
      + status                    = (known after apply)
      + zone                      = "ru-central1-b"

      + boot_disk {
          + auto_delete = true
          + device_name = (known after apply)
          + disk_id     = (known after apply)
          + mode        = (known after apply)

          + initialize_params {
              + block_size  = (known after apply)
              + description = (known after apply)
              + image_id    = "fd8ue2nph2v23d0rtfug"
              + name        = (known after apply)
              + size        = 10
              + snapshot_id = (known after apply)
              + type        = "network-hdd"
            }
        }

      + network_interface {
          + index              = (known after apply)
          + ip_address         = (known after apply)
          + ipv4               = true
          + ipv6               = (known after apply)
          + ipv6_address       = (known after apply)
          + mac_address        = (known after apply)
          + nat                = true
          + nat_ip_address     = (known after apply)
          + nat_ip_version     = (known after apply)
          + security_group_ids = (known after apply)
          + subnet_id          = (known after apply)
        }

      + resources {
          + core_fraction = 100
          + cores         = 4
          + memory        = 8
        }

      + scheduling_policy {
          + preemptible = true
        }
    }

  # yandex_lb_network_load_balancer.nlb-grafana will be created
  + resource "yandex_lb_network_load_balancer" "nlb-grafana" {
      + created_at          = (known after apply)
      + deletion_protection = (known after apply)
      + folder_id           = (known after apply)
      + id                  = (known after apply)
      + name                = "grafana"
      + region_id           = (known after apply)
      + type                = "external"

      + attached_target_group {
          + target_group_id = (known after apply)

          + healthcheck {
              + healthy_threshold   = 2
              + interval            = 2
              + name                = "healthcheck"
              + timeout             = 1
              + unhealthy_threshold = 2

              + tcp_options {
                  + port = 30050
                }
            }
        }

      + listener {
          + name        = "grafana-listener"
          + port        = 3000
          + protocol    = (known after apply)
          + target_port = 30050

          + external_address_spec {
              + address    = (known after apply)
              + ip_version = "ipv4"
            }
        }
    }

  # yandex_lb_network_load_balancer.nlb-web-app will be created
  + resource "yandex_lb_network_load_balancer" "nlb-web-app" {
      + created_at          = (known after apply)
      + deletion_protection = (known after apply)
      + folder_id           = (known after apply)
      + id                  = (known after apply)
      + name                = "web-app"
      + region_id           = (known after apply)
      + type                = "external"

      + attached_target_group {
          + target_group_id = (known after apply)

          + healthcheck {
              + healthy_threshold   = 2
              + interval            = 2
              + name                = "healthcheck"
              + timeout             = 1
              + unhealthy_threshold = 2

              + tcp_options {
                  + port = 30051
                }
            }
        }

      + listener {
          + name        = "web-app-listener"
          + port        = 80
          + protocol    = (known after apply)
          + target_port = 30051

          + external_address_spec {
              + address    = (known after apply)
              + ip_version = "ipv4"
            }
        }
    }

  # yandex_lb_target_group.balancer-group will be created
  + resource "yandex_lb_target_group" "balancer-group" {
      + created_at = (known after apply)
      + folder_id  = (known after apply)
      + id         = (known after apply)
      + name       = "balancer-group"
      + region_id  = (known after apply)

      + target {
          + address   = (known after apply)
          + subnet_id = (known after apply)
        }
      + target {
          + address   = (known after apply)
          + subnet_id = (known after apply)
        }
    }

  # yandex_vpc_network.diplom will be created
  + resource "yandex_vpc_network" "diplom" {
      + created_at                = (known after apply)
      + default_security_group_id = (known after apply)
      + folder_id                 = (known after apply)
      + id                        = (known after apply)
      + labels                    = (known after apply)
      + name                      = "diplom"
      + subnet_ids                = (known after apply)
    }

  # yandex_vpc_subnet.diplom-subnet1 will be created
  + resource "yandex_vpc_subnet" "diplom-subnet1" {
      + created_at     = (known after apply)
      + folder_id      = (known after apply)
      + id             = (known after apply)
      + labels         = (known after apply)
      + name           = "diplom-subnet1"
      + network_id     = (known after apply)
      + v4_cidr_blocks = [
          + "10.0.1.0/24",
        ]
      + v6_cidr_blocks = (known after apply)
      + zone           = "ru-central1-a"
    }

  # yandex_vpc_subnet.diplom-subnet2 will be created
  + resource "yandex_vpc_subnet" "diplom-subnet2" {
      + created_at     = (known after apply)
      + folder_id      = (known after apply)
      + id             = (known after apply)
      + labels         = (known after apply)
      + name           = "diplom-subnet2"
      + network_id     = (known after apply)
      + v4_cidr_blocks = [
          + "10.0.2.0/24",
        ]
      + v6_cidr_blocks = (known after apply)
      + zone           = "ru-central1-b"
    }

Plan: 10 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + Grafana_Network_Load_Balancer_Address = [
      + (known after apply),
    ]
  + Web_App_Network_Load_Balancer_Address = [
      + (known after apply),
    ]
  + all_vms                               = [
      + {
          + ip_external = (known after apply)
          + ip_internal = (known after apply)
          + name        = "master"
        },
      + {
          + ip_external = (known after apply)
          + ip_internal = (known after apply)
          + name        = "worker-1"
        },
      + {
          + ip_external = (known after apply)
          + ip_internal = (known after apply)
          + name        = "worker-2"
        },
    ]
yandex_vpc_network.diplom: Creating...
yandex_vpc_network.diplom: Creation complete after 2s [id=enpgdackc84gpe6dko81]
yandex_vpc_subnet.diplom-subnet1: Creating...
yandex_vpc_subnet.diplom-subnet2: Creating...
yandex_vpc_subnet.diplom-subnet2: Creation complete after 0s [id=e2lkraib7m57t0n5v1o2]
yandex_vpc_subnet.diplom-subnet1: Creation complete after 1s [id=e9bhtdi3o5p8h9fj00dc]
yandex_compute_instance.master[0]: Creating...
yandex_compute_instance.master[0]: Still creating... [10s elapsed]
yandex_compute_instance.master[0]: Still creating... [20s elapsed]
yandex_compute_instance.master[0]: Still creating... [30s elapsed]
yandex_compute_instance.master[0]: Still creating... [40s elapsed]
yandex_compute_instance.master[0]: Still creating... [50s elapsed]
yandex_compute_instance.master[0]: Still creating... [1m0s elapsed]
yandex_compute_instance.master[0]: Creation complete after 1m0s [id=fhm4du4coc4ft6u1b175]
yandex_compute_instance.worker[1]: Creating...
yandex_compute_instance.worker[0]: Creating...
yandex_compute_instance.worker[0]: Still creating... [10s elapsed]
yandex_compute_instance.worker[1]: Still creating... [10s elapsed]
yandex_compute_instance.worker[1]: Still creating... [20s elapsed]
yandex_compute_instance.worker[0]: Still creating... [20s elapsed]
yandex_compute_instance.worker[0]: Still creating... [30s elapsed]
yandex_compute_instance.worker[1]: Still creating... [30s elapsed]
yandex_compute_instance.worker[0]: Still creating... [40s elapsed]
yandex_compute_instance.worker[1]: Still creating... [40s elapsed]
yandex_compute_instance.worker[0]: Creation complete after 40s [id=epdl2m039p4qcjrqmqlt]
yandex_compute_instance.worker[1]: Creation complete after 40s [id=epdmqkgkg6a9obv8u841]
yandex_lb_target_group.balancer-group: Creating...
local_file.hosts_cfg_kubespray[0]: Creating...
local_file.hosts_cfg_kubespray[0]: Creation complete after 0s [id=4c379cd508367c473a801dd25f3afeb7bfbc2918]
yandex_lb_target_group.balancer-group: Creation complete after 2s [id=enpufkghtkgb4m91pjka]
yandex_lb_network_load_balancer.nlb-grafana: Creating...
yandex_lb_network_load_balancer.nlb-grafana: Creation complete after 3s [id=enplhaiut18jk9tl6kva]
yandex_lb_network_load_balancer.nlb-web-app: Creating...
yandex_lb_network_load_balancer.nlb-web-app: Creation complete after 3s [id=enpoak8qmkog1esob5n2]

Apply complete! Resources: 10 added, 0 changed, 0 destroyed.

Outputs:

Grafana_Network_Load_Balancer_Address = tolist([
  "51.250.34.196",
])
Web_App_Network_Load_Balancer_Address = tolist([
  "51.250.43.205",
])
all_vms = [
  {
    "ip_external" = "89.169.130.245"
    "ip_internal" = "10.0.1.13"
    "name" = "master"
  },
  {
    "ip_external" = "89.169.160.6"
    "ip_internal" = "10.0.2.31"
    "name" = "worker-1"
  },
  {
    "ip_external" = "89.169.162.145"
    "ip_internal" = "10.0.2.17"
    "name" = "worker-2"
  },
]
```

Кроме создания сети, подсетей и виртуальных машин, создается ресурс из файла `ansible.tf`, который по шаблону `hosts.tftpl` создает inventory файл. Этот inventory файл в дальнейшем будет использоваться для развёртывания Kubernetes кластера из репозитория Kubespray.

Также при развёртывании виртуальных машин буду использовать файл `cloud-init.yml`, который установит на них полезные в дальнейшем пакеты. Например, curl, Git, MC, atop и другие.

Код для создания Master ноды находится в файле [master.tf](terraform/master.tf)

Код для создания Worker нод находится в файле [worker.tf](terraform/worker.tf)

Код для установки необходимых пакетов на виртуальные машины при их развертывании находится в файле [cloud-init.yml](terraform/cloud-init.yml)

Проверю, создались ли виртуальные машины:

```bash
╰─➤yc compute instance list
+----------------------+----------+---------------+---------+----------------+-------------+
|          ID          |   NAME   |    ZONE ID    | STATUS  |  EXTERNAL IP   | INTERNAL IP |
+----------------------+----------+---------------+---------+----------------+-------------+
| epdl2m039p4qcjrqmqlt | worker-1 | ru-central1-b | RUNNING | 89.169.160.6   | 10.0.2.31   |
| epdmqkgkg6a9obv8u841 | worker-2 | ru-central1-b | RUNNING | 89.169.162.145 | 10.0.2.17   |
| fhm4du4coc4ft6u1b175 | master   | ru-central1-a | RUNNING | 89.169.130.245 | 10.0.1.13   |
+----------------------+----------+---------------+---------+----------------+-------------+
```

Виртуальные машины созданы в разных подсетях и разных зонах доступности.

Также проверю все созданные ресурсы через графический интерфейс:

* Сервисный аккаунт:

![img01_service.png](img/img01_service.png)

* S3-bucket:

![img02_bucket.png](img/img02_bucket.png)

* Сеть и подсети:

![img03_network.png](img/img03_network.png)

* Виртуальные машины:

![img04_vm.png](img/img04_vm.png)

Проверю удаление созданных ресурсов. Удалю созданные виртуальные машины, сеть, подсети:

```bash
╰─➤terraform destroy -auto-approve
data.template_file.cloudinit: Reading...
data.template_file.cloudinit: Read complete after 0s [id=f95b9145823e7854baf57a6dcb4d770613300f5382900a7a1abd3831abed7c6b]
data.yandex_compute_image.ubuntu-master: Reading...
data.yandex_compute_image.ubuntu-worker: Reading...
yandex_vpc_network.diplom: Refreshing state... [id=enpgdackc84gpe6dko81]
data.yandex_compute_image.ubuntu-master: Read complete after 0s [id=fd8ue2nph2v23d0rtfug]
data.yandex_compute_image.ubuntu-worker: Read complete after 0s [id=fd8ue2nph2v23d0rtfug]
yandex_vpc_subnet.diplom-subnet2: Refreshing state... [id=e2lkraib7m57t0n5v1o2]
yandex_vpc_subnet.diplom-subnet1: Refreshing state... [id=e9bhtdi3o5p8h9fj00dc]
yandex_compute_instance.master[0]: Refreshing state... [id=fhm4du4coc4ft6u1b175]
yandex_compute_instance.worker[0]: Refreshing state... [id=epdl2m039p4qcjrqmqlt]
yandex_compute_instance.worker[1]: Refreshing state... [id=epdmqkgkg6a9obv8u841]
yandex_lb_target_group.balancer-group: Refreshing state... [id=enpufkghtkgb4m91pjka]
local_file.hosts_cfg_kubespray[0]: Refreshing state... [id=4c379cd508367c473a801dd25f3afeb7bfbc2918]
yandex_lb_network_load_balancer.nlb-grafana: Refreshing state... [id=enplhaiut18jk9tl6kva]
yandex_lb_network_load_balancer.nlb-web-app: Refreshing state... [id=enpoak8qmkog1esob5n2]

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  - destroy

Terraform will perform the following actions:

  # local_file.hosts_cfg_kubespray[0] will be destroyed
  - resource "local_file" "hosts_cfg_kubespray" {
      - content              = <<-EOT
            all:
              hosts:
                master:
                  ansible_host: 89.169.130.245
                  ip: 10.0.1.13
                  access_ip: 89.169.130.245
                worker-1:
                  ansible_host: 89.169.160.6
                  ip: 10.0.2.31
                  access_ip: 89.169.160.6
                worker-2:
                  ansible_host: 89.169.162.145
                  ip: 10.0.2.17
                  access_ip: 89.169.162.145
              children:
                kube_control_plane:
                  hosts:
                    master:
                kube_node:
                  hosts:
                    worker-1:
                    worker-2:
                etcd:
                  hosts:
                    master:
                k8s_cluster:
                  children:
                    kube_control_plane:
                    kube_node:
                calico_rr:
                  hosts: {}
        EOT -> null
      - content_base64sha256 = "Qqpz+ctFfeGf77FSeM4TvC9PWC47eciUMKQBpvdlsjw=" -> null
      - content_base64sha512 = "phvFt7jSvSiPSXTyIC8N+NwVhkkxYmvnefS5/wvEa6bIEPU8tGnIAzVVSGAuir3knLhUqqAJXD7y5s12V8rOxA==" -> null
      - content_md5          = "4b0afc1c08f0f381162ea514bcc7ba71" -> null
      - content_sha1         = "4c379cd508367c473a801dd25f3afeb7bfbc2918" -> null
      - content_sha256       = "42aa73f9cb457de19fefb15278ce13bc2f4f582e3b79c89430a401a6f765b23c" -> null
      - content_sha512       = "a61bc5b7b8d2bd288f4974f2202f0df8dc15864931626be779f4b9ff0bc46ba6c810f53cb469c803355548602e8abde49cb854aaa0095c3ef2e6cd7657cacec4" -> null
      - directory_permission = "0777" -> null
      - file_permission      = "0777" -> null
      - filename             = "../../kubespray/inventory/mycluster/hosts.yaml" -> null
      - id                   = "4c379cd508367c473a801dd25f3afeb7bfbc2918" -> null
    }

  # yandex_compute_instance.master[0] will be destroyed
  - resource "yandex_compute_instance" "master" {
      - allow_stopping_for_update = true -> null
      - created_at                = "2024-08-11T16:46:29Z" -> null
      - folder_id                 = "b1gl6dqee4o5qromajnb" -> null
      - fqdn                      = "fhm4du4coc4ft6u1b175.auto.internal" -> null
      - id                        = "fhm4du4coc4ft6u1b175" -> null
      - labels                    = {} -> null
      - metadata                  = {
          - "serial-port-enable" = "1"
          - "ssh-keys"           = <<-EOT
                ubuntu:ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBl5/crtWIqG261tg/WA/bbDS3XWFJS8McPXaHDnrP6S LotsmanSM@mail.ru
            EOT
          - "user-data"          = <<-EOT
                #cloud-config
                users:
                  - name: ubuntu
                    groups: sudo
                    shell: /bin/bash
                    sudo: ['ALL=(ALL) NOPASSWD:ALL']
                    ssh_authorized_keys:
                      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBl5/crtWIqG261tg/WA/bbDS3XWFJS8McPXaHDnrP6S LotsmanSM@mail.ru
                
                package_update: true
                package_upgrade: false
                packages:
                  - mc
                  - git
                  - apt-transport-https
                  - ca-certificates
                  - curl
                  - gnupg
                  - lsb-release
                  - unattended-upgrades
                
                runcmd:
                  - curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
                  - chmod 700 get_helm.sh
                  - ./get_helm.sh
            EOT
        } -> null
      - name                      = "master" -> null
      - network_acceleration_type = "standard" -> null
      - platform_id               = "standard-v1" -> null
      - status                    = "running" -> null
      - zone                      = "ru-central1-a" -> null

      - boot_disk {
          - auto_delete = true -> null
          - device_name = "fhmq4cgl8vvje7gr7035" -> null
          - disk_id     = "fhmq4cgl8vvje7gr7035" -> null
          - mode        = "READ_WRITE" -> null

          - initialize_params {
              - block_size = 4096 -> null
              - image_id   = "fd8ue2nph2v23d0rtfug" -> null
              - size       = 10 -> null
              - type       = "network-hdd" -> null
            }
        }

      - metadata_options {
          - aws_v1_http_endpoint = 1 -> null
          - aws_v1_http_token    = 2 -> null
          - gce_http_endpoint    = 1 -> null
          - gce_http_token       = 1 -> null
        }

      - network_interface {
          - index              = 0 -> null
          - ip_address         = "10.0.1.13" -> null
          - ipv4               = true -> null
          - ipv6               = false -> null
          - mac_address        = "d0:0d:46:f8:8c:c3" -> null
          - nat                = true -> null
          - nat_ip_address     = "89.169.130.245" -> null
          - nat_ip_version     = "IPV4" -> null
          - security_group_ids = [] -> null
          - subnet_id          = "e9bhtdi3o5p8h9fj00dc" -> null
        }

      - placement_policy {
          - host_affinity_rules       = [] -> null
          - placement_group_partition = 0 -> null
        }

      - resources {
          - core_fraction = 5 -> null
          - cores         = 2 -> null
          - gpus          = 0 -> null
          - memory        = 4 -> null
        }

      - scheduling_policy {
          - preemptible = true -> null
        }
    }

  # yandex_compute_instance.worker[0] will be destroyed
  - resource "yandex_compute_instance" "worker" {
      - allow_stopping_for_update = true -> null
      - created_at                = "2024-08-11T16:47:29Z" -> null
      - folder_id                 = "b1gl6dqee4o5qromajnb" -> null
      - fqdn                      = "epdl2m039p4qcjrqmqlt.auto.internal" -> null
      - id                        = "epdl2m039p4qcjrqmqlt" -> null
      - labels                    = {} -> null
      - metadata                  = {
          - "serial-port-enable" = "1"
          - "ssh-keys"           = <<-EOT
                ubuntu:ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBl5/crtWIqG261tg/WA/bbDS3XWFJS8McPXaHDnrP6S LotsmanSM@mail.ru
            EOT
          - "user-data"          = <<-EOT
                #cloud-config
                users:
                  - name: ubuntu
                    groups: sudo
                    shell: /bin/bash
                    sudo: ['ALL=(ALL) NOPASSWD:ALL']
                    ssh_authorized_keys:
                      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBl5/crtWIqG261tg/WA/bbDS3XWFJS8McPXaHDnrP6S LotsmanSM@mail.ru
                
                package_update: true
                package_upgrade: false
                packages:
                  - mc
                  - git
                  - apt-transport-https
                  - ca-certificates
                  - curl
                  - gnupg
                  - lsb-release
                  - unattended-upgrades
                
                runcmd:
                  - curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
                  - chmod 700 get_helm.sh
                  - ./get_helm.sh
            EOT
        } -> null
      - name                      = "worker-1" -> null
      - network_acceleration_type = "standard" -> null
      - platform_id               = "standard-v1" -> null
      - status                    = "running" -> null
      - zone                      = "ru-central1-b" -> null

      - boot_disk {
          - auto_delete = true -> null
          - device_name = "epdps3o1t53bi4mcute7" -> null
          - disk_id     = "epdps3o1t53bi4mcute7" -> null
          - mode        = "READ_WRITE" -> null

          - initialize_params {
              - block_size = 4096 -> null
              - image_id   = "fd8ue2nph2v23d0rtfug" -> null
              - size       = 10 -> null
              - type       = "network-hdd" -> null
            }
        }

      - metadata_options {
          - aws_v1_http_endpoint = 1 -> null
          - aws_v1_http_token    = 2 -> null
          - gce_http_endpoint    = 1 -> null
          - gce_http_token       = 1 -> null
        }

      - network_interface {
          - index              = 0 -> null
          - ip_address         = "10.0.2.31" -> null
          - ipv4               = true -> null
          - ipv6               = false -> null
          - mac_address        = "d0:0d:15:15:80:34" -> null
          - nat                = true -> null
          - nat_ip_address     = "89.169.160.6" -> null
          - nat_ip_version     = "IPV4" -> null
          - security_group_ids = [] -> null
          - subnet_id          = "e2lkraib7m57t0n5v1o2" -> null
        }

      - placement_policy {
          - host_affinity_rules       = [] -> null
          - placement_group_partition = 0 -> null
        }

      - resources {
          - core_fraction = 100 -> null
          - cores         = 4 -> null
          - gpus          = 0 -> null
          - memory        = 8 -> null
        }

      - scheduling_policy {
          - preemptible = true -> null
        }
    }

  # yandex_compute_instance.worker[1] will be destroyed
  - resource "yandex_compute_instance" "worker" {
      - allow_stopping_for_update = true -> null
      - created_at                = "2024-08-11T16:47:29Z" -> null
      - folder_id                 = "b1gl6dqee4o5qromajnb" -> null
      - fqdn                      = "epdmqkgkg6a9obv8u841.auto.internal" -> null
      - id                        = "epdmqkgkg6a9obv8u841" -> null
      - labels                    = {} -> null
      - metadata                  = {
          - "serial-port-enable" = "1"
          - "ssh-keys"           = <<-EOT
                ubuntu:ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBl5/crtWIqG261tg/WA/bbDS3XWFJS8McPXaHDnrP6S LotsmanSM@mail.ru
            EOT
          - "user-data"          = <<-EOT
                #cloud-config
                users:
                  - name: ubuntu
                    groups: sudo
                    shell: /bin/bash
                    sudo: ['ALL=(ALL) NOPASSWD:ALL']
                    ssh_authorized_keys:
                      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBl5/crtWIqG261tg/WA/bbDS3XWFJS8McPXaHDnrP6S LotsmanSM@mail.ru
                
                package_update: true
                package_upgrade: false
                packages:
                  - mc
                  - git
                  - apt-transport-https
                  - ca-certificates
                  - curl
                  - gnupg
                  - lsb-release
                  - unattended-upgrades
                
                runcmd:
                  - curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
                  - chmod 700 get_helm.sh
                  - ./get_helm.sh
            EOT
        } -> null
      - name                      = "worker-2" -> null
      - network_acceleration_type = "standard" -> null
      - platform_id               = "standard-v1" -> null
      - status                    = "running" -> null
      - zone                      = "ru-central1-b" -> null

      - boot_disk {
          - auto_delete = true -> null
          - device_name = "epdhv5vuj5rf61cs31tq" -> null
          - disk_id     = "epdhv5vuj5rf61cs31tq" -> null
          - mode        = "READ_WRITE" -> null

          - initialize_params {
              - block_size = 4096 -> null
              - image_id   = "fd8ue2nph2v23d0rtfug" -> null
              - size       = 10 -> null
              - type       = "network-hdd" -> null
            }
        }

      - metadata_options {
          - aws_v1_http_endpoint = 1 -> null
          - aws_v1_http_token    = 2 -> null
          - gce_http_endpoint    = 1 -> null
          - gce_http_token       = 1 -> null
        }

      - network_interface {
          - index              = 0 -> null
          - ip_address         = "10.0.2.17" -> null
          - ipv4               = true -> null
          - ipv6               = false -> null
          - mac_address        = "d0:0d:16:d5:21:48" -> null
          - nat                = true -> null
          - nat_ip_address     = "89.169.162.145" -> null
          - nat_ip_version     = "IPV4" -> null
          - security_group_ids = [] -> null
          - subnet_id          = "e2lkraib7m57t0n5v1o2" -> null
        }

      - placement_policy {
          - host_affinity_rules       = [] -> null
          - placement_group_partition = 0 -> null
        }

      - resources {
          - core_fraction = 100 -> null
          - cores         = 4 -> null
          - gpus          = 0 -> null
          - memory        = 8 -> null
        }

      - scheduling_policy {
          - preemptible = true -> null
        }
    }

  # yandex_lb_network_load_balancer.nlb-grafana will be destroyed
  - resource "yandex_lb_network_load_balancer" "nlb-grafana" {
      - created_at          = "2024-08-11T16:48:11Z" -> null
      - deletion_protection = false -> null
      - folder_id           = "b1gl6dqee4o5qromajnb" -> null
      - id                  = "enplhaiut18jk9tl6kva" -> null
      - labels              = {} -> null
      - name                = "grafana" -> null
      - region_id           = "ru-central1" -> null
      - type                = "external" -> null

      - attached_target_group {
          - target_group_id = "enpufkghtkgb4m91pjka" -> null

          - healthcheck {
              - healthy_threshold   = 2 -> null
              - interval            = 2 -> null
              - name                = "healthcheck" -> null
              - timeout             = 1 -> null
              - unhealthy_threshold = 2 -> null

              - tcp_options {
                  - port = 30050 -> null
                }
            }
        }

      - listener {
          - name        = "grafana-listener" -> null
          - port        = 3000 -> null
          - protocol    = "tcp" -> null
          - target_port = 30050 -> null

          - external_address_spec {
              - address    = "51.250.34.196" -> null
              - ip_version = "ipv4" -> null
            }
        }
    }

  # yandex_lb_network_load_balancer.nlb-web-app will be destroyed
  - resource "yandex_lb_network_load_balancer" "nlb-web-app" {
      - created_at          = "2024-08-11T16:48:14Z" -> null
      - deletion_protection = false -> null
      - folder_id           = "b1gl6dqee4o5qromajnb" -> null
      - id                  = "enpoak8qmkog1esob5n2" -> null
      - labels              = {} -> null
      - name                = "web-app" -> null
      - region_id           = "ru-central1" -> null
      - type                = "external" -> null

      - attached_target_group {
          - target_group_id = "enpufkghtkgb4m91pjka" -> null

          - healthcheck {
              - healthy_threshold   = 2 -> null
              - interval            = 2 -> null
              - name                = "healthcheck" -> null
              - timeout             = 1 -> null
              - unhealthy_threshold = 2 -> null

              - tcp_options {
                  - port = 30051 -> null
                }
            }
        }

      - listener {
          - name        = "web-app-listener" -> null
          - port        = 80 -> null
          - protocol    = "tcp" -> null
          - target_port = 30051 -> null

          - external_address_spec {
              - address    = "51.250.43.205" -> null
              - ip_version = "ipv4" -> null
            }
        }
    }

  # yandex_lb_target_group.balancer-group will be destroyed
  - resource "yandex_lb_target_group" "balancer-group" {
      - created_at = "2024-08-11T16:48:09Z" -> null
      - folder_id  = "b1gl6dqee4o5qromajnb" -> null
      - id         = "enpufkghtkgb4m91pjka" -> null
      - labels     = {} -> null
      - name       = "balancer-group" -> null
      - region_id  = "ru-central1" -> null

      - target {
          - address   = "10.0.2.17" -> null
          - subnet_id = "e2lkraib7m57t0n5v1o2" -> null
        }
      - target {
          - address   = "10.0.2.31" -> null
          - subnet_id = "e2lkraib7m57t0n5v1o2" -> null
        }
    }

  # yandex_vpc_network.diplom will be destroyed
  - resource "yandex_vpc_network" "diplom" {
      - created_at                = "2024-08-11T16:46:25Z" -> null
      - default_security_group_id = "enpa7v55rqdeh5j6j9bc" -> null
      - folder_id                 = "b1gl6dqee4o5qromajnb" -> null
      - id                        = "enpgdackc84gpe6dko81" -> null
      - labels                    = {} -> null
      - name                      = "diplom" -> null
      - subnet_ids                = [
          - "e2lkraib7m57t0n5v1o2",
          - "e9bhtdi3o5p8h9fj00dc",
        ] -> null
    }

  # yandex_vpc_subnet.diplom-subnet1 will be destroyed
  - resource "yandex_vpc_subnet" "diplom-subnet1" {
      - created_at     = "2024-08-11T16:46:28Z" -> null
      - folder_id      = "b1gl6dqee4o5qromajnb" -> null
      - id             = "e9bhtdi3o5p8h9fj00dc" -> null
      - labels         = {} -> null
      - name           = "diplom-subnet1" -> null
      - network_id     = "enpgdackc84gpe6dko81" -> null
      - v4_cidr_blocks = [
          - "10.0.1.0/24",
        ] -> null
      - v6_cidr_blocks = [] -> null
      - zone           = "ru-central1-a" -> null
    }

  # yandex_vpc_subnet.diplom-subnet2 will be destroyed
  - resource "yandex_vpc_subnet" "diplom-subnet2" {
      - created_at     = "2024-08-11T16:46:27Z" -> null
      - folder_id      = "b1gl6dqee4o5qromajnb" -> null
      - id             = "e2lkraib7m57t0n5v1o2" -> null
      - labels         = {} -> null
      - name           = "diplom-subnet2" -> null
      - network_id     = "enpgdackc84gpe6dko81" -> null
      - v4_cidr_blocks = [
          - "10.0.2.0/24",
        ] -> null
      - v6_cidr_blocks = [] -> null
      - zone           = "ru-central1-b" -> null
    }

Plan: 0 to add, 0 to change, 10 to destroy.

Changes to Outputs:
  - Grafana_Network_Load_Balancer_Address = [
      - "51.250.34.196",
    ] -> null
  - Web_App_Network_Load_Balancer_Address = [
      - "51.250.43.205",
    ] -> null
  - all_vms                               = [
      - {
          - ip_external = "89.169.130.245"
          - ip_internal = "10.0.1.13"
          - name        = "master"
        },
      - {
          - ip_external = "89.169.160.6"
          - ip_internal = "10.0.2.31"
          - name        = "worker-1"
        },
      - {
          - ip_external = "89.169.162.145"
          - ip_internal = "10.0.2.17"
          - name        = "worker-2"
        },
    ] -> null
local_file.hosts_cfg_kubespray[0]: Destroying... [id=4c379cd508367c473a801dd25f3afeb7bfbc2918]
local_file.hosts_cfg_kubespray[0]: Destruction complete after 0s
yandex_lb_network_load_balancer.nlb-web-app: Destroying... [id=enpoak8qmkog1esob5n2]
yandex_lb_network_load_balancer.nlb-web-app: Destruction complete after 2s
yandex_lb_network_load_balancer.nlb-grafana: Destroying... [id=enplhaiut18jk9tl6kva]
yandex_lb_network_load_balancer.nlb-grafana: Destruction complete after 3s
yandex_lb_target_group.balancer-group: Destroying... [id=enpufkghtkgb4m91pjka]
yandex_lb_target_group.balancer-group: Destruction complete after 2s
yandex_compute_instance.worker[0]: Destroying... [id=epdl2m039p4qcjrqmqlt]
yandex_compute_instance.worker[1]: Destroying... [id=epdmqkgkg6a9obv8u841]
yandex_compute_instance.worker[1]: Still destroying... [id=epdmqkgkg6a9obv8u841, 10s elapsed]
yandex_compute_instance.worker[0]: Still destroying... [id=epdl2m039p4qcjrqmqlt, 10s elapsed]
yandex_compute_instance.worker[0]: Still destroying... [id=epdl2m039p4qcjrqmqlt, 20s elapsed]
yandex_compute_instance.worker[1]: Still destroying... [id=epdmqkgkg6a9obv8u841, 20s elapsed]
yandex_compute_instance.worker[0]: Still destroying... [id=epdl2m039p4qcjrqmqlt, 30s elapsed]
yandex_compute_instance.worker[1]: Still destroying... [id=epdmqkgkg6a9obv8u841, 30s elapsed]
yandex_compute_instance.worker[1]: Still destroying... [id=epdmqkgkg6a9obv8u841, 40s elapsed]
yandex_compute_instance.worker[0]: Still destroying... [id=epdl2m039p4qcjrqmqlt, 40s elapsed]
yandex_compute_instance.worker[0]: Destruction complete after 47s
yandex_compute_instance.worker[1]: Still destroying... [id=epdmqkgkg6a9obv8u841, 50s elapsed]
yandex_compute_instance.worker[1]: Destruction complete after 53s
yandex_vpc_subnet.diplom-subnet2: Destroying... [id=e2lkraib7m57t0n5v1o2]
yandex_compute_instance.master[0]: Destroying... [id=fhm4du4coc4ft6u1b175]
yandex_vpc_subnet.diplom-subnet2: Destruction complete after 3s
yandex_compute_instance.master[0]: Still destroying... [id=fhm4du4coc4ft6u1b175, 10s elapsed]
yandex_compute_instance.master[0]: Still destroying... [id=fhm4du4coc4ft6u1b175, 20s elapsed]
yandex_compute_instance.master[0]: Still destroying... [id=fhm4du4coc4ft6u1b175, 30s elapsed]
yandex_compute_instance.master[0]: Still destroying... [id=fhm4du4coc4ft6u1b175, 40s elapsed]
yandex_compute_instance.master[0]: Still destroying... [id=fhm4du4coc4ft6u1b175, 50s elapsed]
yandex_compute_instance.master[0]: Destruction complete after 55s
yandex_vpc_subnet.diplom-subnet1: Destroying... [id=e9bhtdi3o5p8h9fj00dc]
yandex_vpc_subnet.diplom-subnet1: Destruction complete after 3s
yandex_vpc_network.diplom: Destroying... [id=enpgdackc84gpe6dko81]
yandex_vpc_network.diplom: Destruction complete after 1s

Destroy complete! Resources: 10 destroyed.
```

Удалю сервисный аккаунт, статический ключ и S3-bucket:

```bash
╰─➤terraform destroy -auto-approve
yandex_iam_service_account.service: Refreshing state... [id=aje7cftietvodb39sfn9]
yandex_resourcemanager_folder_iam_member.service_editor: Refreshing state... [id=b1gl6dqee4o5qromajnb/editor/serviceAccount:aje7cftietvodb39sfn9]
yandex_iam_service_account_static_access_key.terraform_service_account_key: Refreshing state... [id=ajekmuv72g6k56r4kk47]
yandex_storage_bucket.tf-bucket: Refreshing state... [id=lsm-diplom-bucket]

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  - destroy

Terraform will perform the following actions:

  # yandex_iam_service_account.service will be destroyed
  - resource "yandex_iam_service_account" "service" {
      - created_at = "2024-08-11T16:38:24Z" -> null
      - folder_id  = "b1gl6dqee4o5qromajnb" -> null
      - id         = "aje7cftietvodb39sfn9" -> null
      - name       = "service" -> null
    }

  # yandex_iam_service_account_static_access_key.terraform_service_account_key will be destroyed
  - resource "yandex_iam_service_account_static_access_key" "terraform_service_account_key" {
      - access_key         = "YCAJEEzR7VH5QJ8PNDhFcsxuD" -> null
      - created_at         = "2024-08-11T16:38:27Z" -> null
      - id                 = "ajekmuv72g6k56r4kk47" -> null
      - secret_key         = (sensitive value) -> null
      - service_account_id = "aje7cftietvodb39sfn9" -> null
    }

  # yandex_resourcemanager_folder_iam_member.service_editor will be destroyed
  - resource "yandex_resourcemanager_folder_iam_member" "service_editor" {
      - folder_id = "b1gl6dqee4o5qromajnb" -> null
      - id        = "b1gl6dqee4o5qromajnb/editor/serviceAccount:aje7cftietvodb39sfn9" -> null
      - member    = "serviceAccount:aje7cftietvodb39sfn9" -> null
      - role      = "editor" -> null
    }

  # yandex_storage_bucket.tf-bucket will be destroyed
  - resource "yandex_storage_bucket" "tf-bucket" {
      - access_key            = "YCAJEEzR7VH5QJ8PNDhFcsxuD" -> null
      - bucket                = "lsm-diplom-bucket" -> null
      - bucket_domain_name    = "lsm-diplom-bucket.storage.yandexcloud.net" -> null
      - default_storage_class = "STANDARD" -> null
      - folder_id             = "b1gl6dqee4o5qromajnb" -> null
      - force_destroy         = true -> null
      - id                    = "lsm-diplom-bucket" -> null
      - max_size              = 1073741824 -> null
      - secret_key            = (sensitive value) -> null
      - tags                  = {} -> null

      - anonymous_access_flags {
          - config_read = false -> null
          - list        = false -> null
          - read        = false -> null
        }

      - versioning {
          - enabled = false -> null
        }
    }

Plan: 0 to add, 0 to change, 4 to destroy.
yandex_resourcemanager_folder_iam_member.service_editor: Destroying... [id=b1gl6dqee4o5qromajnb/editor/serviceAccount:aje7cftietvodb39sfn9]
yandex_storage_bucket.tf-bucket: Destroying... [id=lsm-diplom-bucket]
yandex_resourcemanager_folder_iam_member.service_editor: Destruction complete after 4s
yandex_storage_bucket.tf-bucket: Still destroying... [id=lsm-diplom-bucket, 10s elapsed]
yandex_storage_bucket.tf-bucket: Destruction complete after 11s
yandex_iam_service_account_static_access_key.terraform_service_account_key: Destroying... [id=ajekmuv72g6k56r4kk47]
yandex_iam_service_account_static_access_key.terraform_service_account_key: Destruction complete after 1s
yandex_iam_service_account.service: Destroying... [id=aje7cftietvodb39sfn9]
yandex_iam_service_account.service: Destruction complete after 5s

Destroy complete! Resources: 4 destroyed.
```

Созданные виртуальные машины, сеть, подсети, сервисный аккаунт, статический ключ и S3-bucket удаляются успешно.

Настрою автоматическое применение, удаление и обновление кода Terraform. Для этого воспользуюсь GitHub Actions. Пишу Workflow, который позволит запускать применение и удаление кода Terraform по условиям через события `workflow_dispatch`. При нажатии на кнопку `Run workflow` видим два условия, одно из них при введении `true` запустит создание инфраструктуры, другое при введении `true` запустит её удаление:

![img05_workflow1.png](img/img05_workflow1.png)

Также при `git push` кода Terraform в `main` ветку репозитория запустится автоматическое применение этого кода. Это необходимо для автоматического обновления облачной конфигурации при изменении каких либо ресурсов.

Скриншот работы Workflow при обновлении конфигурации облачной инфраструктуры:

![img06_workflow2.png](img/img06_workflow2.png)

[Код Workflow](.github/workflows/terraform-cloud.yml)

[Выполненные GitHub Actions](https://github.com/LotsmanSM/DevOps-35-diplom-yc/actions)

[Полный код Terraform для создания сервисного аккаунта, статического ключа и S3-bucket](terraform-s3/)

[Полный код Terraform для создания сети, подсетей, виртуальных машин](terraform/)

В ходе выполнения работы код может быть изменен и дополнен.

---
### Создание Kubernetes кластера

На этом этапе необходимо создать [Kubernetes](https://kubernetes.io/ru/docs/concepts/overview/what-is-kubernetes/) кластер на базе предварительно созданной инфраструктуры. Требуется обеспечить доступ к ресурсам из Интернета.

Это можно сделать двумя способами:

1. Рекомендуемый вариант: самостоятельная установка Kubernetes кластера.  
   а. При помощи Terraform подготовить как минимум 3 виртуальных машины Compute Cloud для создания Kubernetes-кластера. Тип виртуальной машины следует выбрать самостоятельно с учётом требовании к производительности и стоимости. Если в дальнейшем поймете, что необходимо сменить тип инстанса, используйте Terraform для внесения изменений.  
   б. Подготовить [ansible](https://www.ansible.com/) конфигурации, можно воспользоваться, например [Kubespray](https://kubernetes.io/docs/setup/production-environment/tools/kubespray/)  
   в. Задеплоить Kubernetes на подготовленные ранее инстансы, в случае нехватки каких-либо ресурсов вы всегда можете создать их при помощи Terraform.
2. Альтернативный вариант: воспользуйтесь сервисом [Yandex Managed Service for Kubernetes](https://cloud.yandex.ru/services/managed-kubernetes)  
  а. С помощью terraform resource для [kubernetes](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/kubernetes_cluster) создать **региональный** мастер kubernetes с размещением нод в разных 3 подсетях      
  б. С помощью terraform resource для [kubernetes node group](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/kubernetes_node_group)
  
Ожидаемый результат:

1. Работоспособный Kubernetes кластер.
2. В файле `~/.kube/config` находятся данные для доступа к кластеру.
3. Команда `kubectl get pods --all-namespaces` отрабатывает без ошибок.

### Выполнение этапа "Создание Kubernetes кластера":

После развёртывания облачной инфраструктуры, приступаю к развёртыванию Kubernetes кластера.

Разворачивать буду из репозитория Kubespray.

Клонирую репозиторий на свою рабочую машину:

```bash
╰─➤git clone https://github.com/kubernetes-sigs/kubespray
Клонирование в «kubespray»...
remote: Enumerating objects: 75954, done.
remote: Counting objects: 100% (802/802), done.
remote: Compressing objects: 100% (557/557), done.
remote: Total 75954 (delta 232), reused 641 (delta 138), pack-reused 75152 (from 1)
Получение объектов: 100% (75954/75954), 24.07 МиБ | 8.76 МиБ/с, готово.
Определение изменений: 100% (42734/42734), готово.
```
При разворачивании облачной инфраструктуры с помощью Terraform применяется следующий код:

```
resource "local_file" "hosts_cfg_kubespray" {
  content  = templatefile("${path.module}/hosts.tftpl", {
    workers = yandex_compute_instance.worker
    masters = yandex_compute_instance.master
  })
  filename = "../kubespray/inventory/mycluster/hosts.yaml"
}
```
Этот код по пути /kubespray/inventory/mycluster/ создаст файл `hosts.yaml` и по шаблону автоматически заполнит его ip адресами нод.

Сам файл шаблона выглядит следующим образом:

```
all:
  hosts:%{ for idx, master in masters }
    master:
      ansible_host: ${master.network_interface[0].nat_ip_address}
      ip: ${master.network_interface[0].ip_address}
      access_ip: ${master.network_interface[0].nat_ip_address}%{ endfor }%{ for idx, worker in workers }
    worker-${idx + 1}:
      ansible_host: ${worker.network_interface[0].nat_ip_address}
      ip: ${worker.network_interface[0].ip_address}
      access_ip: ${worker.network_interface[0].nat_ip_address}%{ endfor }
  children:
    kube_control_plane:
      hosts:%{ for idx, master in masters }
        ${master.name}:%{ endfor }
    kube_node:
      hosts:%{ for idx, worker in workers }
        ${worker.name}:%{ endfor }
    etcd:
      hosts:%{ for idx, master in masters }
        ${master.name}:%{ endfor }
    k8s_cluster:
      children:
        kube_control_plane:
        kube_node:
    calico_rr:
      hosts: {}
```

Перейду в директорию `kubespray` и установлю необходимые для установки K8S компоненты

```bash
╰─➤sudo apt update

╰─➤sudo apt install git python3 python3-pip -y

╰─➤pip install -r requirements.txt
Defaulting to user installation because normal site-packages is not writeable
Requirement already satisfied: ansible==9.8.0 in /usr/lib/python3/dist-packages (from -r requirements.txt (line 1)) (9.8.0)
Collecting jmespath==1.0.1
  Downloading jmespath-1.0.1-py3-none-any.whl (20 kB)
Collecting jsonschema==4.23.0
  Downloading jsonschema-4.23.0-py3-none-any.whl (88 kB)
     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 88.5/88.5 KB 831.2 kB/s eta 0:00:00
Collecting netaddr==1.3.0
  Downloading netaddr-1.3.0-py3-none-any.whl (2.3 MB)
     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 2.3/2.3 MB 7.0 MB/s eta 0:00:00
Collecting attrs>=22.2.0
  Downloading attrs-24.2.0-py3-none-any.whl (63 kB)
     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 63.0/63.0 KB 10.2 MB/s eta 0:00:00
Collecting referencing>=0.28.4
  Downloading referencing-0.35.1-py3-none-any.whl (26 kB)
Collecting jsonschema-specifications>=2023.03.6
  Downloading jsonschema_specifications-2023.12.1-py3-none-any.whl (18 kB)
Collecting rpds-py>=0.7.1
  Downloading rpds_py-0.20.0-cp310-cp310-manylinux_2_17_x86_64.manylinux2014_x86_64.whl (354 kB)
     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 354.8/354.8 KB 20.0 MB/s eta 0:00:00
Installing collected packages: rpds-py, netaddr, jmespath, attrs, referencing, jsonschema-specifications, jsonschema
  WARNING: The script netaddr is installed in '/home/serg/.local/bin' which is not on PATH.
  Consider adding this directory to PATH or, if you prefer to suppress this warning, use --no-warn-script-location.
  WARNING: The script jsonschema is installed in '/home/serg/.local/bin' which is not on PATH.
  Consider adding this directory to PATH or, if you prefer to suppress this warning, use --no-warn-script-location.
Successfully installed attrs-24.2.0 jmespath-1.0.1 jsonschema-4.23.0 jsonschema-specifications-2023.12.1 netaddr-1.3.0 referencing-0.35.1 rpds-py-0.20.0
```

Запущу установку kubernetes кластера командой

```bash
╰─➤nsible-playbook -i inventory/mycluster/hosts.yaml -u ubuntu --become --become-user=root --private-key=~/.ssh/id_ed25519 -e 'ansible_ssh_common_args="-o StrictHostKeyChecking=no"' cluster.yml --flush-cache
[WARNING]: While constructing a mapping from /home/serg/DevOps-35-diplom-yc/kubespray/roles/bootstrap-os/tasks/main.yml, line 29, column 7, found a duplicate dict
key (paths). Using last defined value only.
[WARNING]: Skipping callback plugin 'ara_default', unable to load

PLAY [Check Ansible version] *****************************************************************************************************************************************
Воскресенье 18 августа 2024  23:44:24 +0300 (0:00:00.014)       0:00:00.014 *** 

TASK [Check 2.16.4 <= Ansible version < 2.17.0] **********************************************************************************************************************
ok: [master] => {
    "changed": false,
    "msg": "All assertions passed"
}
Воскресенье 18 августа 2024  23:44:24 +0300 (0:00:00.021)       0:00:00.036 *** 

TASK [Check that python netaddr is installed] ************************************************************************************************************************
ok: [master] => {
    "changed": false,
    "msg": "All assertions passed"
}
Воскресенье 18 августа 2024  23:44:24 +0300 (0:00:00.051)       0:00:00.087 *** 

TASK [Check that jinja is not too old (install via pip)] *************************************************************************************************************
ok: [master] => {
    "changed": false,
    "msg": "All assertions passed"
}
[WARNING]: Could not match supplied host pattern, ignoring: kube-master

PLAY [Add kube-master nodes to kube_control_plane] *******************************************************************************************************************
skipping: no hosts matched
[WARNING]: Could not match supplied host pattern, ignoring: kube-node

PLAY [Add kube-node nodes to kube_node] ******************************************************************************************************************************
skipping: no hosts matched
[WARNING]: Could not match supplied host pattern, ignoring: k8s-cluster

PLAY [Add k8s-cluster nodes to k8s_cluster] **************************************************************************************************************************
skipping: no hosts matched
[WARNING]: Could not match supplied host pattern, ignoring: calico-rr

PLAY [Add calico-rr nodes to calico_rr] ******************************************************************************************************************************
skipping: no hosts matched
[WARNING]: Could not match supplied host pattern, ignoring: no-floating

PLAY [Add no-floating nodes to no_floating] **************************************************************************************************************************
skipping: no hosts matched
[WARNING]: Could not match supplied host pattern, ignoring: bastion

PLAY [Install bastion ssh config] ************************************************************************************************************************************
skipping: no hosts matched

PLAY [Bootstrap hosts for Ansible] ***********************************************************************************************************************************
Воскресенье 18 августа 2024  23:44:24 +0300 (0:00:00.042)       0:00:00.130 *** 
Воскресенье 18 августа 2024  23:44:24 +0300 (0:00:00.041)       0:00:00.171 *** 
Воскресенье 18 августа 2024  23:44:24 +0300 (0:00:00.025)       0:00:00.197 *** 
Воскресенье 18 августа 2024  23:44:24 +0300 (0:00:00.039)       0:00:00.236 *** 
Воскресенье 18 августа 2024  23:44:24 +0300 (0:00:00.025)       0:00:00.261 *** 
Воскресенье 18 августа 2024  23:44:24 +0300 (0:00:00.037)       0:00:00.298 *** 
Воскресенье 18 августа 2024  23:44:24 +0300 (0:00:00.033)       0:00:00.332 *** 
[WARNING]: raw module does not support the environment keyword

TASK [bootstrap-os : Fetch /etc/os-release] **************************************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:44:25 +0300 (0:00:00.091)       0:00:00.424 *** 
Воскресенье 18 августа 2024  23:44:25 +0300 (0:00:00.054)       0:00:00.478 *** 

TASK [bootstrap-os : Include tasks] **********************************************************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/bootstrap-os/tasks/ubuntu.yml for master, worker-1, worker-2 => (item=/home/serg/DevOps-35-diplom-yc/kubespray/roles/bootstrap-os/tasks/ubuntu.yml)
Воскресенье 18 августа 2024  23:44:25 +0300 (0:00:00.065)       0:00:00.544 *** 

TASK [bootstrap-os : Check if bootstrap is needed] *******************************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:44:25 +0300 (0:00:00.089)       0:00:00.633 *** 

TASK [bootstrap-os : Check http::proxy in apt configuration files] ***************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:44:25 +0300 (0:00:00.096)       0:00:00.729 *** 
Воскресенье 18 августа 2024  23:44:25 +0300 (0:00:00.031)       0:00:00.761 *** 

TASK [bootstrap-os : Check https::proxy in apt configuration files] **************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:44:25 +0300 (0:00:00.097)       0:00:00.858 *** 
Воскресенье 18 августа 2024  23:44:25 +0300 (0:00:00.031)       0:00:00.890 *** 
Воскресенье 18 августа 2024  23:44:25 +0300 (0:00:00.026)       0:00:00.916 *** 
Воскресенье 18 августа 2024  23:44:25 +0300 (0:00:00.126)       0:00:01.043 *** 
Воскресенье 18 августа 2024  23:44:25 +0300 (0:00:00.127)       0:00:01.170 *** 

TASK [bootstrap-os : Create remote_tmp for it is used by another module] *********************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:44:26 +0300 (0:00:00.864)       0:00:02.035 *** 

TASK [bootstrap-os : Gather facts] ***********************************************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:44:27 +0300 (0:00:01.249)       0:00:03.284 *** 

TASK [bootstrap-os : Assign inventory name to unconfigured hostnames (non-CoreOS, non-Flatcar, Suse and ClearLinux, non-Fedora)] *************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:44:29 +0300 (0:00:01.256)       0:00:04.541 *** 
Воскресенье 18 августа 2024  23:44:29 +0300 (0:00:00.042)       0:00:04.584 *** 

TASK [bootstrap-os : Ensure bash_completion.d folder exists] *********************************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]

PLAY [Gather facts] **************************************************************************************************************************************************
Воскресенье 18 августа 2024  23:44:29 +0300 (0:00:00.653)       0:00:05.237 *** 

TASK [Gather minimal facts] ******************************************************************************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:44:30 +0300 (0:00:00.652)       0:00:05.889 *** 

TASK [Gather necessary facts (network)] ******************************************************************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:44:31 +0300 (0:00:00.621)       0:00:06.511 *** 

TASK [Gather necessary facts (hardware)] *****************************************************************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]

PLAY [Prepare for etcd install] **************************************************************************************************************************************
Воскресенье 18 августа 2024  23:44:32 +0300 (0:00:01.166)       0:00:07.678 *** 
Воскресенье 18 августа 2024  23:44:32 +0300 (0:00:00.060)       0:00:07.738 *** 

TASK [kubespray-defaults : Create fallback_ips_base] *****************************************************************************************************************
ok: [master -> localhost]
Воскресенье 18 августа 2024  23:44:32 +0300 (0:00:00.045)       0:00:07.783 *** 

TASK [kubespray-defaults : Set fallback_ips] *************************************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:44:32 +0300 (0:00:00.061)       0:00:07.844 *** 
Воскресенье 18 августа 2024  23:44:32 +0300 (0:00:00.032)       0:00:07.877 *** 
Воскресенье 18 августа 2024  23:44:32 +0300 (0:00:00.052)       0:00:07.930 *** 
Воскресенье 18 августа 2024  23:44:32 +0300 (0:00:00.049)       0:00:07.979 *** 

TASK [adduser : User | Create User Group] ****************************************************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:44:32 +0300 (0:00:00.380)       0:00:08.360 *** 

TASK [adduser : User | Create User] **********************************************************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:44:33 +0300 (0:00:00.548)       0:00:08.908 *** 

TASK [kubernetes/preinstall : Check if /etc/fstab exists] ************************************************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:44:33 +0300 (0:00:00.368)       0:00:09.276 *** 

TASK [kubernetes/preinstall : Remove swapfile from /etc/fstab] *******************************************************************************************************
ok: [worker-1] => (item=swap)
ok: [master] => (item=swap)
ok: [worker-2] => (item=swap)
ok: [worker-1] => (item=none)
ok: [master] => (item=none)
ok: [worker-2] => (item=none)
Воскресенье 18 августа 2024  23:44:34 +0300 (0:00:00.640)       0:00:09.916 *** 

TASK [kubernetes/preinstall : Mask swap.target (persist swapoff)] ****************************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:44:35 +0300 (0:00:00.738)       0:00:10.655 *** 

TASK [kubernetes/preinstall : Disable swap] **************************************************************************************************************************
changed: [worker-1]
changed: [master]
changed: [worker-2]
Воскресенье 18 августа 2024  23:44:35 +0300 (0:00:00.366)       0:00:11.021 *** 
Воскресенье 18 августа 2024  23:44:35 +0300 (0:00:00.036)       0:00:11.057 *** 

TASK [kubernetes/preinstall : Check resolvconf] **********************************************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:44:35 +0300 (0:00:00.300)       0:00:11.358 *** 

TASK [kubernetes/preinstall : Check existence of /etc/resolvconf/resolv.conf.d] **************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:44:36 +0300 (0:00:00.299)       0:00:11.657 *** 

TASK [kubernetes/preinstall : Check status of /etc/resolv.conf] ******************************************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:44:36 +0300 (0:00:00.306)       0:00:11.964 *** 

TASK [kubernetes/preinstall : Get content of /etc/resolv.conf] *******************************************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:44:36 +0300 (0:00:00.358)       0:00:12.322 *** 

TASK [kubernetes/preinstall : Get currently configured nameservers] **************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:44:36 +0300 (0:00:00.085)       0:00:12.408 *** 

TASK [kubernetes/preinstall : Stop if /etc/resolv.conf not configured nameservers] ***********************************************************************************
ok: [master] => {
    "changed": false,
    "msg": "All assertions passed"
}
ok: [worker-1] => {
    "changed": false,
    "msg": "All assertions passed"
}
ok: [worker-2] => {
    "changed": false,
    "msg": "All assertions passed"
}
Воскресенье 18 августа 2024  23:44:37 +0300 (0:00:00.062)       0:00:12.470 *** 

TASK [kubernetes/preinstall : NetworkManager | Check if host has NetworkManager] *************************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:44:37 +0300 (0:00:00.311)       0:00:12.782 *** 

TASK [kubernetes/preinstall : Check systemd-resolved] ****************************************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:44:37 +0300 (0:00:00.306)       0:00:13.089 *** 

TASK [kubernetes/preinstall : Set default dns if remove_default_searchdomains is false] ******************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:44:37 +0300 (0:00:00.061)       0:00:13.150 *** 

TASK [kubernetes/preinstall : Set dns facts] *************************************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:44:37 +0300 (0:00:00.066)       0:00:13.216 *** 

TASK [kubernetes/preinstall : Check if kubelet is configured] ********************************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:44:38 +0300 (0:00:00.285)       0:00:13.502 *** 

TASK [kubernetes/preinstall : Check if early DNS configuration stage] ************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:44:38 +0300 (0:00:00.052)       0:00:13.554 *** 

TASK [kubernetes/preinstall : Target resolv.conf files] **************************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:44:38 +0300 (0:00:00.056)       0:00:13.611 *** 
Воскресенье 18 августа 2024  23:44:38 +0300 (0:00:00.035)       0:00:13.647 *** 

TASK [kubernetes/preinstall : Check if /etc/dhclient.conf exists] ****************************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:44:38 +0300 (0:00:00.292)       0:00:13.939 *** 
Воскресенье 18 августа 2024  23:44:38 +0300 (0:00:00.036)       0:00:13.976 *** 

TASK [kubernetes/preinstall : Check if /etc/dhcp/dhclient.conf exists] ***********************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:44:38 +0300 (0:00:00.297)       0:00:14.273 *** 

TASK [kubernetes/preinstall : Target dhclient conf file for /etc/dhcp/dhclient.conf] *********************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:44:38 +0300 (0:00:00.053)       0:00:14.326 *** 
Воскресенье 18 августа 2024  23:44:38 +0300 (0:00:00.034)       0:00:14.361 *** 

TASK [kubernetes/preinstall : Target dhclient hook file for Debian family] *******************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:44:39 +0300 (0:00:00.061)       0:00:14.422 *** 

TASK [kubernetes/preinstall : Generate search domains to resolvconf] *************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:44:39 +0300 (0:00:00.062)       0:00:14.485 *** 

TASK [kubernetes/preinstall : Pick coredns cluster IP or default resolver] *******************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:44:39 +0300 (0:00:00.095)       0:00:14.581 *** 
Воскресенье 18 августа 2024  23:44:39 +0300 (0:00:00.040)       0:00:14.621 *** 

TASK [kubernetes/preinstall : Generate nameservers for resolvconf, not including cluster DNS] ************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:44:39 +0300 (0:00:00.061)       0:00:14.683 *** 

TASK [kubernetes/preinstall : Generate supersede_nameserver from dhclient_supersede_nameserver_entries_list] *********************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:44:39 +0300 (0:00:00.058)       0:00:14.741 *** 
Воскресенье 18 августа 2024  23:44:39 +0300 (0:00:00.040)       0:00:14.782 *** 

TASK [kubernetes/preinstall : Check /usr readonly] *******************************************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:44:39 +0300 (0:00:00.305)       0:00:15.087 *** 
Воскресенье 18 августа 2024  23:44:39 +0300 (0:00:00.039)       0:00:15.127 *** 

TASK [kubernetes/preinstall : Stop if either kube_control_plane or kube_node group is empty] *************************************************************************
ok: [master] => {
    "changed": false,
    "msg": "All assertions passed"
}
Воскресенье 18 августа 2024  23:44:39 +0300 (0:00:00.033)       0:00:15.160 *** 

TASK [kubernetes/preinstall : Stop if etcd group is empty in external etcd mode] *************************************************************************************
ok: [master] => {
    "changed": false,
    "msg": "All assertions passed"
}
Воскресенье 18 августа 2024  23:44:39 +0300 (0:00:00.033)       0:00:15.194 *** 

TASK [kubernetes/preinstall : Stop if non systemd OS type] ***********************************************************************************************************
ok: [master] => {
    "changed": false,
    "msg": "All assertions passed"
}
ok: [worker-1] => {
    "changed": false,
    "msg": "All assertions passed"
}
ok: [worker-2] => {
    "changed": false,
    "msg": "All assertions passed"
}
Воскресенье 18 августа 2024  23:44:39 +0300 (0:00:00.054)       0:00:15.249 *** 

TASK [kubernetes/preinstall : Stop if the os does not support] *******************************************************************************************************
ok: [master] => {
    "changed": false,
    "msg": "All assertions passed"
}
ok: [worker-1] => {
    "changed": false,
    "msg": "All assertions passed"
}
ok: [worker-2] => {
    "changed": false,
    "msg": "All assertions passed"
}
Воскресенье 18 августа 2024  23:44:39 +0300 (0:00:00.051)       0:00:15.301 *** 

TASK [kubernetes/preinstall : Stop if unknown network plugin] ********************************************************************************************************
ok: [master] => {
    "changed": false,
    "msg": "All assertions passed"
}
ok: [worker-1] => {
    "changed": false,
    "msg": "All assertions passed"
}
ok: [worker-2] => {
    "changed": false,
    "msg": "All assertions passed"
}
Воскресенье 18 августа 2024  23:44:39 +0300 (0:00:00.055)       0:00:15.357 *** 

TASK [kubernetes/preinstall : Stop if unsupported version of Kubernetes] *********************************************************************************************
ok: [master] => {
    "changed": false,
    "msg": "All assertions passed"
}
ok: [worker-1] => {
    "changed": false,
    "msg": "All assertions passed"
}
ok: [worker-2] => {
    "changed": false,
    "msg": "All assertions passed"
}
Воскресенье 18 августа 2024  23:44:39 +0300 (0:00:00.054)       0:00:15.411 *** 

TASK [kubernetes/preinstall : Stop if known booleans are set as strings (Use JSON format on CLI: -e "{'key': true }")] ***********************************************
ok: [master] => (item={'name': 'download_run_once', 'value': False}) => {
    "ansible_loop_var": "item",
    "changed": false,
    "item": {
        "name": "download_run_once",
        "value": false
    },
    "msg": "All assertions passed"
}
ok: [master] => (item={'name': 'deploy_netchecker', 'value': False}) => {
    "ansible_loop_var": "item",
    "changed": false,
    "item": {
        "name": "deploy_netchecker",
        "value": false
    },
    "msg": "All assertions passed"
}
ok: [master] => (item={'name': 'download_always_pull', 'value': False}) => {
    "ansible_loop_var": "item",
    "changed": false,
    "item": {
        "name": "download_always_pull",
        "value": false
    },
    "msg": "All assertions passed"
}
ok: [master] => (item={'name': 'helm_enabled', 'value': False}) => {
    "ansible_loop_var": "item",
    "changed": false,
    "item": {
        "name": "helm_enabled",
        "value": false
    },
    "msg": "All assertions passed"
}
ok: [master] => (item={'name': 'openstack_lbaas_enabled', 'value': False}) => {
    "ansible_loop_var": "item",
    "changed": false,
    "item": {
        "name": "openstack_lbaas_enabled",
        "value": false
    },
    "msg": "All assertions passed"
}
Воскресенье 18 августа 2024  23:44:40 +0300 (0:00:00.060)       0:00:15.472 *** 

TASK [kubernetes/preinstall : Stop if even number of etcd hosts] *****************************************************************************************************
ok: [master] => {
    "changed": false,
    "msg": "All assertions passed"
}
Воскресенье 18 августа 2024  23:44:40 +0300 (0:00:00.037)       0:00:15.509 *** 

TASK [kubernetes/preinstall : Stop if memory is too small for masters] ***********************************************************************************************
ok: [master] => {
    "changed": false,
    "msg": "All assertions passed"
}
Воскресенье 18 августа 2024  23:44:40 +0300 (0:00:00.038)       0:00:15.547 *** 

TASK [kubernetes/preinstall : Stop if memory is too small for nodes] *************************************************************************************************
ok: [worker-1] => {
    "changed": false,
    "msg": "All assertions passed"
}
ok: [worker-2] => {
    "changed": false,
    "msg": "All assertions passed"
}
Воскресенье 18 августа 2024  23:44:40 +0300 (0:00:00.053)       0:00:15.601 *** 

TASK [kubernetes/preinstall : Stop if cgroups are not enabled on nodes] **********************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:44:40 +0300 (0:00:00.325)       0:00:15.926 *** 
Воскресенье 18 августа 2024  23:44:40 +0300 (0:00:00.043)       0:00:15.970 *** 

TASK [kubernetes/preinstall : Stop if ip var does not match local ips] ***********************************************************************************************
ok: [master] => {
    "changed": false,
    "msg": "All assertions passed"
}
ok: [worker-1] => {
    "changed": false,
    "msg": "All assertions passed"
}
ok: [worker-2] => {
    "changed": false,
    "msg": "All assertions passed"
}
Воскресенье 18 августа 2024  23:44:40 +0300 (0:00:00.055)       0:00:16.025 *** 

TASK [kubernetes/preinstall : Ensure ping package] *******************************************************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:44:42 +0300 (0:00:01.561)       0:00:17.586 *** 

TASK [kubernetes/preinstall : Stop if access_ip is not pingable] *****************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:44:42 +0300 (0:00:00.336)       0:00:17.923 *** 
Воскресенье 18 августа 2024  23:44:42 +0300 (0:00:00.036)       0:00:17.960 *** 
Воскресенье 18 августа 2024  23:44:42 +0300 (0:00:00.045)       0:00:18.005 *** 
Воскресенье 18 августа 2024  23:44:42 +0300 (0:00:00.047)       0:00:18.053 *** 

TASK [kubernetes/preinstall : Stop if bad hostname] ******************************************************************************************************************
ok: [master] => {
    "changed": false,
    "msg": "All assertions passed"
}
ok: [worker-1] => {
    "changed": false,
    "msg": "All assertions passed"
}
ok: [worker-2] => {
    "changed": false,
    "msg": "All assertions passed"
}
Воскресенье 18 августа 2024  23:44:42 +0300 (0:00:00.053)       0:00:18.107 *** 
Воскресенье 18 августа 2024  23:44:42 +0300 (0:00:00.041)       0:00:18.148 *** 

TASK [kubernetes/preinstall : Check that kube_service_addresses is a network range] **********************************************************************************
ok: [master] => {
    "changed": false,
    "msg": "All assertions passed"
}
Воскресенье 18 августа 2024  23:44:42 +0300 (0:00:00.059)       0:00:18.207 *** 

TASK [kubernetes/preinstall : Check that kube_pods_subnet is a network range] ****************************************************************************************
ok: [master] => {
    "changed": false,
    "msg": "All assertions passed"
}
Воскресенье 18 августа 2024  23:44:42 +0300 (0:00:00.060)       0:00:18.267 *** 

TASK [kubernetes/preinstall : Check that kube_pods_subnet does not collide with kube_service_addresses] **************************************************************
ok: [master] => {
    "changed": false,
    "msg": "All assertions passed"
}
Воскресенье 18 августа 2024  23:44:42 +0300 (0:00:00.067)       0:00:18.335 *** 
Воскресенье 18 августа 2024  23:44:42 +0300 (0:00:00.017)       0:00:18.353 *** 

TASK [kubernetes/preinstall : Stop if unknown dns mode] **************************************************************************************************************
ok: [master] => {
    "changed": false,
    "msg": "All assertions passed"
}
Воскресенье 18 августа 2024  23:44:42 +0300 (0:00:00.035)       0:00:18.388 *** 

TASK [kubernetes/preinstall : Stop if unknown kube proxy mode] *******************************************************************************************************
ok: [master] => {
    "changed": false,
    "msg": "All assertions passed"
}
Воскресенье 18 августа 2024  23:44:43 +0300 (0:00:00.036)       0:00:18.425 *** 

TASK [kubernetes/preinstall : Stop if unknown cert_management] *******************************************************************************************************
ok: [master] => {
    "changed": false,
    "msg": "All assertions passed"
}
Воскресенье 18 августа 2024  23:44:43 +0300 (0:00:00.033)       0:00:18.458 *** 

TASK [kubernetes/preinstall : Stop if unknown resolvconf_mode] *******************************************************************************************************
ok: [master] => {
    "changed": false,
    "msg": "All assertions passed"
}
Воскресенье 18 августа 2024  23:44:43 +0300 (0:00:00.035)       0:00:18.494 *** 

TASK [kubernetes/preinstall : Stop if etcd deployment type is not host, docker or kubeadm] ***************************************************************************
ok: [master] => {
    "changed": false,
    "msg": "All assertions passed"
}
Воскресенье 18 августа 2024  23:44:43 +0300 (0:00:00.035)       0:00:18.530 *** 

TASK [kubernetes/preinstall : Stop if container manager is not docker, crio or containerd] ***************************************************************************
ok: [master] => {
    "changed": false,
    "msg": "All assertions passed"
}
Воскресенье 18 августа 2024  23:44:43 +0300 (0:00:00.032)       0:00:18.562 *** 

TASK [kubernetes/preinstall : Stop if etcd deployment type is not host or kubeadm when container_manager != docker] **************************************************
ok: [master] => {
    "changed": false,
    "msg": "All assertions passed"
}
Воскресенье 18 августа 2024  23:44:43 +0300 (0:00:00.038)       0:00:18.601 *** 
Воскресенье 18 августа 2024  23:44:43 +0300 (0:00:00.021)       0:00:18.623 *** 
Воскресенье 18 августа 2024  23:44:43 +0300 (0:00:00.021)       0:00:18.644 *** 
Воскресенье 18 августа 2024  23:44:43 +0300 (0:00:00.036)       0:00:18.681 *** 
Воскресенье 18 августа 2024  23:44:43 +0300 (0:00:00.037)       0:00:18.718 *** 
Воскресенье 18 августа 2024  23:44:43 +0300 (0:00:00.035)       0:00:18.754 *** 
Воскресенье 18 августа 2024  23:44:43 +0300 (0:00:00.036)       0:00:18.790 *** 

TASK [kubernetes/preinstall : Ensure minimum containerd version] *****************************************************************************************************
ok: [master] => {
    "changed": false,
    "msg": "All assertions passed"
}
Воскресенье 18 августа 2024  23:44:43 +0300 (0:00:00.035)       0:00:18.826 *** 
Воскресенье 18 августа 2024  23:44:43 +0300 (0:00:00.041)       0:00:18.868 *** 
Воскресенье 18 августа 2024  23:44:43 +0300 (0:00:00.036)       0:00:18.904 *** 
Воскресенье 18 августа 2024  23:44:43 +0300 (0:00:00.044)       0:00:18.949 *** 

TASK [kubernetes/preinstall : Verify that the packages list structure is valid] **************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:44:43 +0300 (0:00:00.108)       0:00:19.058 *** 

TASK [kubernetes/preinstall : Verify that the packages list is sorted] ***********************************************************************************************
ok: [master] => {
    "changed": false,
    "msg": "All assertions passed"
}
ok: [worker-1] => {
    "changed": false,
    "msg": "All assertions passed"
}
ok: [worker-2] => {
    "changed": false,
    "msg": "All assertions passed"
}
Воскресенье 18 августа 2024  23:44:43 +0300 (0:00:00.081)       0:00:19.140 *** 

TASK [kubernetes/preinstall : Create kubernetes directories] *********************************************************************************************************
ok: [worker-1] => (item=/etc/kubernetes)
ok: [worker-2] => (item=/etc/kubernetes)
ok: [master] => (item=/etc/kubernetes)
ok: [worker-1] => (item=/etc/kubernetes/manifests)
ok: [worker-2] => (item=/etc/kubernetes/manifests)
ok: [master] => (item=/etc/kubernetes/manifests)
ok: [worker-1] => (item=/usr/local/bin/kubernetes-scripts)
ok: [worker-2] => (item=/usr/local/bin/kubernetes-scripts)
ok: [master] => (item=/usr/local/bin/kubernetes-scripts)
ok: [worker-1] => (item=/usr/libexec/kubernetes/kubelet-plugins/volume/exec)
ok: [worker-2] => (item=/usr/libexec/kubernetes/kubelet-plugins/volume/exec)
ok: [master] => (item=/usr/libexec/kubernetes/kubelet-plugins/volume/exec)
Воскресенье 18 августа 2024  23:44:44 +0300 (0:00:01.253)       0:00:20.394 *** 

TASK [kubernetes/preinstall : Create other directories of root owner] ************************************************************************************************
ok: [worker-1] => (item=/etc/kubernetes/ssl)
ok: [worker-2] => (item=/etc/kubernetes/ssl)
ok: [master] => (item=/etc/kubernetes/ssl)
ok: [worker-1] => (item=/usr/local/bin)
ok: [worker-2] => (item=/usr/local/bin)
ok: [master] => (item=/usr/local/bin)
Воскресенье 18 августа 2024  23:44:45 +0300 (0:00:00.582)       0:00:20.976 *** 

TASK [kubernetes/preinstall : Check if kubernetes kubeadm compat cert dir exists] ************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:44:45 +0300 (0:00:00.301)       0:00:21.278 *** 
Воскресенье 18 августа 2024  23:44:45 +0300 (0:00:00.038)       0:00:21.317 *** 

TASK [kubernetes/preinstall : Create cni directories] ****************************************************************************************************************
ok: [worker-1] => (item=/etc/cni/net.d)
ok: [master] => (item=/etc/cni/net.d)
ok: [worker-2] => (item=/etc/cni/net.d)
ok: [worker-1] => (item=/opt/cni/bin)
ok: [worker-2] => (item=/opt/cni/bin)
ok: [master] => (item=/opt/cni/bin)
Воскресенье 18 августа 2024  23:44:46 +0300 (0:00:00.592)       0:00:21.909 *** 

TASK [kubernetes/preinstall : Create calico cni directories] *********************************************************************************************************
ok: [worker-1] => (item=/var/lib/calico)
ok: [worker-2] => (item=/var/lib/calico)
ok: [master] => (item=/var/lib/calico)
Воскресенье 18 августа 2024  23:44:46 +0300 (0:00:00.324)       0:00:22.233 *** 
Воскресенье 18 августа 2024  23:44:46 +0300 (0:00:00.059)       0:00:22.293 *** 
Воскресенье 18 августа 2024  23:44:46 +0300 (0:00:00.040)       0:00:22.333 *** 
Воскресенье 18 августа 2024  23:44:46 +0300 (0:00:00.038)       0:00:22.371 *** 
Воскресенье 18 августа 2024  23:44:47 +0300 (0:00:00.060)       0:00:22.431 *** 
Воскресенье 18 августа 2024  23:44:47 +0300 (0:00:00.059)       0:00:22.490 *** 
Воскресенье 18 августа 2024  23:44:47 +0300 (0:00:00.036)       0:00:22.527 *** 
Воскресенье 18 августа 2024  23:44:47 +0300 (0:00:00.037)       0:00:22.564 *** 

TASK [kubernetes/preinstall : Create systemd-resolved drop-in directory] *********************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:44:47 +0300 (0:00:00.313)       0:00:22.878 *** 

TASK [kubernetes/preinstall : Write Kubespray DNS settings to systemd-resolved] **************************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:44:48 +0300 (0:00:00.758)       0:00:23.636 *** 
Воскресенье 18 августа 2024  23:44:48 +0300 (0:00:00.037)       0:00:23.674 *** 
Воскресенье 18 августа 2024  23:44:48 +0300 (0:00:00.036)       0:00:23.711 *** 
Воскресенье 18 августа 2024  23:44:48 +0300 (0:00:00.036)       0:00:23.748 *** 
Воскресенье 18 августа 2024  23:44:48 +0300 (0:00:00.036)       0:00:23.784 *** 
Воскресенье 18 августа 2024  23:44:48 +0300 (0:00:00.037)       0:00:23.821 *** 
Воскресенье 18 августа 2024  23:44:48 +0300 (0:00:00.037)       0:00:23.859 *** 
Воскресенье 18 августа 2024  23:44:48 +0300 (0:00:00.037)       0:00:23.896 *** 
Воскресенье 18 августа 2024  23:44:48 +0300 (0:00:00.038)       0:00:23.935 *** 
Воскресенье 18 августа 2024  23:44:48 +0300 (0:00:00.039)       0:00:23.974 *** 
Воскресенье 18 августа 2024  23:44:48 +0300 (0:00:00.038)       0:00:24.013 *** 

TASK [kubernetes/preinstall : Update package management cache (APT)] *************************************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:44:49 +0300 (0:00:00.899)       0:00:24.912 *** 
Воскресенье 18 августа 2024  23:44:49 +0300 (0:00:00.036)       0:00:24.949 *** 
Воскресенье 18 августа 2024  23:44:49 +0300 (0:00:00.037)       0:00:24.986 *** 

TASK [kubernetes/preinstall : Install packages requirements] *********************************************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:44:50 +0300 (0:00:01.361)       0:00:26.347 *** 
Воскресенье 18 августа 2024  23:44:50 +0300 (0:00:00.036)       0:00:26.383 *** 
Воскресенье 18 августа 2024  23:44:51 +0300 (0:00:00.037)       0:00:26.420 *** 
Воскресенье 18 августа 2024  23:44:51 +0300 (0:00:00.035)       0:00:26.456 *** 

TASK [kubernetes/preinstall : Clean previously used sysctl file locations] *******************************************************************************************
ok: [worker-1] => (item=ipv4-ip_forward.conf)
ok: [master] => (item=ipv4-ip_forward.conf)
ok: [worker-2] => (item=ipv4-ip_forward.conf)
ok: [worker-1] => (item=bridge-nf-call.conf)
ok: [master] => (item=bridge-nf-call.conf)
ok: [worker-2] => (item=bridge-nf-call.conf)
Воскресенье 18 августа 2024  23:44:51 +0300 (0:00:00.594)       0:00:27.051 *** 

TASK [kubernetes/preinstall : Stat sysctl file configuration] ********************************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:44:51 +0300 (0:00:00.296)       0:00:27.347 *** 

TASK [kubernetes/preinstall : Change sysctl file path to link source if linked] **************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:44:51 +0300 (0:00:00.060)       0:00:27.408 *** 

TASK [kubernetes/preinstall : Make sure sysctl file path folder exists] **********************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:44:52 +0300 (0:00:00.309)       0:00:27.717 *** 

TASK [kubernetes/preinstall : Enable ip forwarding] ******************************************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:44:52 +0300 (0:00:00.433)       0:00:28.151 *** 
Воскресенье 18 августа 2024  23:44:52 +0300 (0:00:00.046)       0:00:28.197 *** 

TASK [kubernetes/preinstall : Check if we need to set fs.may_detach_mounts] ******************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:44:53 +0300 (0:00:00.296)       0:00:28.494 *** 
Воскресенье 18 августа 2024  23:44:53 +0300 (0:00:00.048)       0:00:28.542 *** 

TASK [kubernetes/preinstall : Ensure kubelet expected parameters are set] ********************************************************************************************
ok: [worker-1] => (item={'name': 'kernel.keys.root_maxbytes', 'value': 25000000})
ok: [worker-2] => (item={'name': 'kernel.keys.root_maxbytes', 'value': 25000000})
ok: [master] => (item={'name': 'kernel.keys.root_maxbytes', 'value': 25000000})
ok: [worker-1] => (item={'name': 'kernel.keys.root_maxkeys', 'value': 1000000})
ok: [worker-2] => (item={'name': 'kernel.keys.root_maxkeys', 'value': 1000000})
ok: [master] => (item={'name': 'kernel.keys.root_maxkeys', 'value': 1000000})
ok: [worker-1] => (item={'name': 'kernel.panic', 'value': 10})
ok: [worker-2] => (item={'name': 'kernel.panic', 'value': 10})
ok: [master] => (item={'name': 'kernel.panic', 'value': 10})
ok: [worker-1] => (item={'name': 'kernel.panic_on_oops', 'value': 1})
ok: [worker-2] => (item={'name': 'kernel.panic_on_oops', 'value': 1})
ok: [master] => (item={'name': 'kernel.panic_on_oops', 'value': 1})
ok: [worker-1] => (item={'name': 'vm.overcommit_memory', 'value': 1})
ok: [worker-2] => (item={'name': 'vm.overcommit_memory', 'value': 1})
ok: [master] => (item={'name': 'vm.overcommit_memory', 'value': 1})
ok: [worker-1] => (item={'name': 'vm.panic_on_oom', 'value': 0})
ok: [worker-2] => (item={'name': 'vm.panic_on_oom', 'value': 0})
ok: [master] => (item={'name': 'vm.panic_on_oom', 'value': 0})
Воскресенье 18 августа 2024  23:44:54 +0300 (0:00:01.724)       0:00:30.266 *** 

TASK [kubernetes/preinstall : Check dummy module] ********************************************************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:44:55 +0300 (0:00:00.454)       0:00:30.720 *** 
Воскресенье 18 августа 2024  23:44:55 +0300 (0:00:00.037)       0:00:30.758 *** 

TASK [kubernetes/preinstall : Disable fapolicyd service] *************************************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:44:55 +0300 (0:00:00.493)       0:00:31.251 *** 
Воскресенье 18 августа 2024  23:44:55 +0300 (0:00:00.038)       0:00:31.290 *** 
Воскресенье 18 августа 2024  23:44:55 +0300 (0:00:00.036)       0:00:31.326 *** 
Воскресенье 18 августа 2024  23:44:55 +0300 (0:00:00.037)       0:00:31.363 *** 
Воскресенье 18 августа 2024  23:44:55 +0300 (0:00:00.036)       0:00:31.400 *** 
Воскресенье 18 августа 2024  23:44:56 +0300 (0:00:00.035)       0:00:31.436 *** 
Воскресенье 18 августа 2024  23:44:56 +0300 (0:00:00.038)       0:00:31.475 *** 
Воскресенье 18 августа 2024  23:44:56 +0300 (0:00:00.036)       0:00:31.511 *** 
Воскресенье 18 августа 2024  23:44:56 +0300 (0:00:00.039)       0:00:31.551 *** 
Воскресенье 18 августа 2024  23:44:56 +0300 (0:00:00.041)       0:00:31.593 *** 

TASK [kubernetes/preinstall : Hosts | create hosts list from inventory] **********************************************************************************************
ok: [master -> localhost]
Воскресенье 18 августа 2024  23:44:56 +0300 (0:00:00.056)       0:00:31.649 *** 

TASK [kubernetes/preinstall : Hosts | populate inventory into hosts file] ********************************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:44:56 +0300 (0:00:00.451)       0:00:32.101 *** 
Воскресенье 18 августа 2024  23:44:56 +0300 (0:00:00.041)       0:00:32.143 *** 

TASK [kubernetes/preinstall : Hosts | Retrieve hosts file content] ***************************************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:44:57 +0300 (0:00:00.291)       0:00:32.434 *** 

TASK [kubernetes/preinstall : Hosts | Extract existing entries for localhost from hosts file] ************************************************************************
ok: [worker-1] => (item=127.0.0.1 localhost localhost.localdomain)
ok: [master] => (item=127.0.0.1 localhost localhost.localdomain)
ok: [worker-1] => (item=::1 ip6-localhost ip6-loopback localhost6 localhost6.localdomain)
ok: [master] => (item=::1 ip6-localhost ip6-loopback localhost6 localhost6.localdomain)
ok: [worker-2] => (item=127.0.0.1 localhost localhost.localdomain)
ok: [worker-2] => (item=::1 ip6-localhost ip6-loopback localhost6 localhost6.localdomain)
Воскресенье 18 августа 2024  23:44:57 +0300 (0:00:00.143)       0:00:32.577 *** 

TASK [kubernetes/preinstall : Hosts | Update target hosts file entries dict with required entries] *******************************************************************
ok: [master] => (item={'key': '127.0.0.1', 'value': {'expected': ['localhost', 'localhost.localdomain']}})
ok: [master] => (item={'key': '::1', 'value': {'expected': ['localhost6', 'localhost6.localdomain'], 'unexpected': ['localhost', 'localhost.localdomain']}})
ok: [worker-1] => (item={'key': '127.0.0.1', 'value': {'expected': ['localhost', 'localhost.localdomain']}})
ok: [worker-1] => (item={'key': '::1', 'value': {'expected': ['localhost6', 'localhost6.localdomain'], 'unexpected': ['localhost', 'localhost.localdomain']}})
ok: [worker-2] => (item={'key': '127.0.0.1', 'value': {'expected': ['localhost', 'localhost.localdomain']}})
ok: [worker-2] => (item={'key': '::1', 'value': {'expected': ['localhost6', 'localhost6.localdomain'], 'unexpected': ['localhost', 'localhost.localdomain']}})
Воскресенье 18 августа 2024  23:44:57 +0300 (0:00:00.069)       0:00:32.647 *** 

TASK [kubernetes/preinstall : Hosts | Update (if necessary) hosts file] **********************************************************************************************
ok: [worker-1] => (item={'key': '127.0.0.1', 'value': ['localhost', 'localhost.localdomain']})
ok: [worker-2] => (item={'key': '127.0.0.1', 'value': ['localhost', 'localhost.localdomain']})
ok: [master] => (item={'key': '127.0.0.1', 'value': ['localhost', 'localhost.localdomain']})
changed: [worker-1] => (item={'key': '::1', 'value': ['localhost6', 'localhost6.localdomain', 'ip6-loopback', 'ip6-localhost']})
changed: [worker-2] => (item={'key': '::1', 'value': ['localhost6', 'localhost6.localdomain', 'ip6-loopback', 'ip6-localhost']})
changed: [master] => (item={'key': '::1', 'value': ['localhost6', 'localhost6.localdomain', 'ip6-loopback', 'ip6-localhost']})
Воскресенье 18 августа 2024  23:44:57 +0300 (0:00:00.701)       0:00:33.348 *** 

TASK [kubernetes/preinstall : Update facts] **************************************************************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:44:58 +0300 (0:00:00.660)       0:00:34.008 *** 

TASK [kubernetes/preinstall : Configure dhclient to supersede search/domain/nameservers] *****************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:44:58 +0300 (0:00:00.306)       0:00:34.315 *** 

TASK [kubernetes/preinstall : Configure dhclient hooks for resolv.conf (non-RH)] *************************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:44:59 +0300 (0:00:00.750)       0:00:35.066 *** 
Воскресенье 18 августа 2024  23:44:59 +0300 (0:00:00.042)       0:00:35.108 *** 
Воскресенье 18 августа 2024  23:44:59 +0300 (0:00:00.039)       0:00:35.148 *** 
Воскресенье 18 августа 2024  23:44:59 +0300 (0:00:00.038)       0:00:35.187 *** 
Воскресенье 18 августа 2024  23:44:59 +0300 (0:00:00.004)       0:00:35.191 *** 
Воскресенье 18 августа 2024  23:44:59 +0300 (0:00:00.004)       0:00:35.195 *** 
Воскресенье 18 августа 2024  23:44:59 +0300 (0:00:00.003)       0:00:35.198 *** 

TASK [kubernetes/preinstall : Check if we are running inside a Azure VM] *********************************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:45:00 +0300 (0:00:00.317)       0:00:35.516 *** 
Воскресенье 18 августа 2024  23:45:00 +0300 (0:00:00.037)       0:00:35.553 *** 
Воскресенье 18 августа 2024  23:45:00 +0300 (0:00:00.035)       0:00:35.589 *** 
Воскресенье 18 августа 2024  23:45:00 +0300 (0:00:00.037)       0:00:35.626 *** 
Воскресенье 18 августа 2024  23:45:00 +0300 (0:00:00.040)       0:00:35.666 *** 
Воскресенье 18 августа 2024  23:45:00 +0300 (0:00:00.040)       0:00:35.707 *** 
Воскресенье 18 августа 2024  23:45:00 +0300 (0:00:00.036)       0:00:35.743 *** 
Воскресенье 18 августа 2024  23:45:00 +0300 (0:00:00.039)       0:00:35.783 *** 

TASK [Run calico checks] *********************************************************************************************************************************************
Воскресенье 18 августа 2024  23:45:00 +0300 (0:00:00.222)       0:00:36.005 *** 

TASK [network_plugin/calico : Stop if legacy encapsulation variables are detected (ipip)] ****************************************************************************
ok: [master] => {
    "changed": false,
    "msg": "All assertions passed"
}
Воскресенье 18 августа 2024  23:45:00 +0300 (0:00:00.040)       0:00:36.046 *** 

TASK [network_plugin/calico : Stop if legacy encapsulation variables are detected (ipip_mode)] ***********************************************************************
ok: [master] => {
    "changed": false,
    "msg": "All assertions passed"
}
Воскресенье 18 августа 2024  23:45:00 +0300 (0:00:00.038)       0:00:36.084 *** 

TASK [network_plugin/calico : Stop if legacy encapsulation variables are detected (calcio_ipam_autoallocateblocks)] **************************************************
ok: [master] => {
    "changed": false,
    "msg": "All assertions passed"
}
Воскресенье 18 августа 2024  23:45:00 +0300 (0:00:00.039)       0:00:36.123 *** 
Воскресенье 18 августа 2024  23:45:00 +0300 (0:00:00.025)       0:00:36.149 *** 

TASK [network_plugin/calico : Stop if supported Calico versions] *****************************************************************************************************
ok: [master] => {
    "changed": false,
    "msg": "All assertions passed"
}
Воскресенье 18 августа 2024  23:45:00 +0300 (0:00:00.036)       0:00:36.185 *** 

TASK [network_plugin/calico : Check if calicoctl.sh exists] **********************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:45:01 +0300 (0:00:00.292)       0:00:36.478 *** 
Воскресенье 18 августа 2024  23:45:01 +0300 (0:00:00.023)       0:00:36.502 *** 
Воскресенье 18 августа 2024  23:45:01 +0300 (0:00:00.022)       0:00:36.524 *** 
Воскресенье 18 августа 2024  23:45:01 +0300 (0:00:00.021)       0:00:36.545 *** 
Воскресенье 18 августа 2024  23:45:01 +0300 (0:00:00.031)       0:00:36.577 *** 
Воскресенье 18 августа 2024  23:45:01 +0300 (0:00:00.021)       0:00:36.598 *** 

TASK [network_plugin/calico : Check vars defined correctly] **********************************************************************************************************
ok: [master] => {
    "changed": false,
    "msg": "All assertions passed"
}
Воскресенье 18 августа 2024  23:45:01 +0300 (0:00:00.041)       0:00:36.640 *** 

TASK [network_plugin/calico : Check calico network backend defined correctly] ****************************************************************************************
ok: [master] => {
    "changed": false,
    "msg": "All assertions passed"
}
Воскресенье 18 августа 2024  23:45:01 +0300 (0:00:00.039)       0:00:36.679 *** 

TASK [network_plugin/calico : Check ipip and vxlan mode defined correctly] *******************************************************************************************
ok: [master] => {
    "changed": false,
    "msg": "All assertions passed"
}
Воскресенье 18 августа 2024  23:45:01 +0300 (0:00:00.038)       0:00:36.717 *** 
Воскресенье 18 августа 2024  23:45:01 +0300 (0:00:00.021)       0:00:36.739 *** 

TASK [network_plugin/calico : Check ipip and vxlan mode if simultaneously enabled] ***********************************************************************************
ok: [master] => {
    "changed": false,
    "msg": "All assertions passed"
}
Воскресенье 18 августа 2024  23:45:01 +0300 (0:00:00.038)       0:00:36.777 *** 

TASK [network_plugin/calico : Get Calico default-pool configuration] *************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:45:01 +0300 (0:00:00.289)       0:00:37.066 *** 
Воскресенье 18 августа 2024  23:45:01 +0300 (0:00:00.021)       0:00:37.088 *** 
Воскресенье 18 августа 2024  23:45:01 +0300 (0:00:00.025)       0:00:37.113 *** 
Воскресенье 18 августа 2024  23:45:01 +0300 (0:00:00.022)       0:00:37.136 *** 
Воскресенье 18 августа 2024  23:45:01 +0300 (0:00:00.021)       0:00:37.158 *** 
Воскресенье 18 августа 2024  23:45:01 +0300 (0:00:00.034)       0:00:37.192 *** 

TASK [container-engine/validate-container-engine : Validate-container-engine | check if fedora coreos] ***************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:45:02 +0300 (0:00:00.321)       0:00:37.514 *** 

TASK [container-engine/validate-container-engine : Validate-container-engine | set is_ostree] ************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:45:02 +0300 (0:00:00.055)       0:00:37.570 *** 

TASK [container-engine/validate-container-engine : Ensure kubelet systemd unit exists] *******************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:45:02 +0300 (0:00:00.297)       0:00:37.867 *** 

TASK [container-engine/validate-container-engine : Populate service facts] *******************************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:45:06 +0300 (0:00:04.002)       0:00:41.870 *** 

TASK [container-engine/validate-container-engine : Check if containerd is installed] *********************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:45:06 +0300 (0:00:00.496)       0:00:42.367 *** 

TASK [container-engine/validate-container-engine : Check if docker is installed] *************************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:45:07 +0300 (0:00:00.356)       0:00:42.723 *** 

TASK [container-engine/validate-container-engine : Check if crio is installed] ***************************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:45:07 +0300 (0:00:00.340)       0:00:43.064 *** 
Воскресенье 18 августа 2024  23:45:07 +0300 (0:00:00.048)       0:00:43.112 *** 
Воскресенье 18 августа 2024  23:45:07 +0300 (0:00:00.046)       0:00:43.159 *** 
Воскресенье 18 августа 2024  23:45:07 +0300 (0:00:00.055)       0:00:43.214 *** 
Воскресенье 18 августа 2024  23:45:07 +0300 (0:00:00.059)       0:00:43.274 *** 
Воскресенье 18 августа 2024  23:45:07 +0300 (0:00:00.087)       0:00:43.361 *** 
Воскресенье 18 августа 2024  23:45:07 +0300 (0:00:00.050)       0:00:43.412 *** 
Воскресенье 18 августа 2024  23:45:08 +0300 (0:00:00.123)       0:00:43.536 *** 
Воскресенье 18 августа 2024  23:45:08 +0300 (0:00:00.049)       0:00:43.585 *** 
Воскресенье 18 августа 2024  23:45:08 +0300 (0:00:00.049)       0:00:43.634 *** 
Воскресенье 18 августа 2024  23:45:08 +0300 (0:00:00.048)       0:00:43.683 *** 
Воскресенье 18 августа 2024  23:45:08 +0300 (0:00:00.067)       0:00:43.750 *** 
Воскресенье 18 августа 2024  23:45:08 +0300 (0:00:00.062)       0:00:43.813 *** 
Воскресенье 18 августа 2024  23:45:08 +0300 (0:00:00.054)       0:00:43.867 *** 
Воскресенье 18 августа 2024  23:45:08 +0300 (0:00:00.049)       0:00:43.917 *** 
Воскресенье 18 августа 2024  23:45:08 +0300 (0:00:00.049)       0:00:43.966 *** 
Воскресенье 18 августа 2024  23:45:08 +0300 (0:00:00.064)       0:00:44.031 *** 
Воскресенье 18 августа 2024  23:45:08 +0300 (0:00:00.055)       0:00:44.086 *** 
Воскресенье 18 августа 2024  23:45:08 +0300 (0:00:00.052)       0:00:44.139 *** 
Воскресенье 18 августа 2024  23:45:08 +0300 (0:00:00.058)       0:00:44.197 *** 
Воскресенье 18 августа 2024  23:45:08 +0300 (0:00:00.089)       0:00:44.286 *** 
Воскресенье 18 августа 2024  23:45:08 +0300 (0:00:00.058)       0:00:44.345 *** 
Воскресенье 18 августа 2024  23:45:08 +0300 (0:00:00.063)       0:00:44.408 *** 
Воскресенье 18 августа 2024  23:45:09 +0300 (0:00:00.056)       0:00:44.465 *** 
Воскресенье 18 августа 2024  23:45:09 +0300 (0:00:00.050)       0:00:44.515 *** 
Воскресенье 18 августа 2024  23:45:09 +0300 (0:00:00.104)       0:00:44.620 *** 
Воскресенье 18 августа 2024  23:45:09 +0300 (0:00:00.062)       0:00:44.683 *** 
Воскресенье 18 августа 2024  23:45:09 +0300 (0:00:00.047)       0:00:44.730 *** 
Воскресенье 18 августа 2024  23:45:09 +0300 (0:00:00.052)       0:00:44.783 *** 
Воскресенье 18 августа 2024  23:45:09 +0300 (0:00:00.047)       0:00:44.831 *** 
Воскресенье 18 августа 2024  23:45:09 +0300 (0:00:00.049)       0:00:44.880 *** 
Воскресенье 18 августа 2024  23:45:09 +0300 (0:00:00.062)       0:00:44.942 *** 
Воскресенье 18 августа 2024  23:45:09 +0300 (0:00:00.052)       0:00:44.995 *** 
Воскресенье 18 августа 2024  23:45:09 +0300 (0:00:00.049)       0:00:45.044 *** 
Воскресенье 18 августа 2024  23:45:09 +0300 (0:00:00.053)       0:00:45.098 *** 
Воскресенье 18 августа 2024  23:45:09 +0300 (0:00:00.054)       0:00:45.152 *** 
Воскресенье 18 августа 2024  23:45:09 +0300 (0:00:00.068)       0:00:45.220 *** 
Воскресенье 18 августа 2024  23:45:09 +0300 (0:00:00.050)       0:00:45.271 *** 
Воскресенье 18 августа 2024  23:45:09 +0300 (0:00:00.065)       0:00:45.336 *** 
Воскресенье 18 августа 2024  23:45:09 +0300 (0:00:00.060)       0:00:45.397 *** 
Воскресенье 18 августа 2024  23:45:10 +0300 (0:00:00.057)       0:00:45.454 *** 
Воскресенье 18 августа 2024  23:45:10 +0300 (0:00:00.053)       0:00:45.508 *** 
Воскресенье 18 августа 2024  23:45:10 +0300 (0:00:00.090)       0:00:45.598 *** 
Воскресенье 18 августа 2024  23:45:10 +0300 (0:00:00.063)       0:00:45.661 *** 
Воскресенье 18 августа 2024  23:45:10 +0300 (0:00:00.058)       0:00:45.720 *** 
Воскресенье 18 августа 2024  23:45:10 +0300 (0:00:00.050)       0:00:45.770 *** 
Воскресенье 18 августа 2024  23:45:10 +0300 (0:00:00.056)       0:00:45.827 *** 
Воскресенье 18 августа 2024  23:45:10 +0300 (0:00:00.056)       0:00:45.884 *** 
Воскресенье 18 августа 2024  23:45:10 +0300 (0:00:00.055)       0:00:45.939 *** 
Воскресенье 18 августа 2024  23:45:10 +0300 (0:00:00.050)       0:00:45.989 *** 
Воскресенье 18 августа 2024  23:45:10 +0300 (0:00:00.050)       0:00:46.040 *** 
Воскресенье 18 августа 2024  23:45:10 +0300 (0:00:00.066)       0:00:46.106 *** 
Воскресенье 18 августа 2024  23:45:10 +0300 (0:00:00.064)       0:00:46.171 *** 
Воскресенье 18 августа 2024  23:45:10 +0300 (0:00:00.049)       0:00:46.221 *** 
Воскресенье 18 августа 2024  23:45:10 +0300 (0:00:00.054)       0:00:46.275 *** 
Воскресенье 18 августа 2024  23:45:10 +0300 (0:00:00.049)       0:00:46.325 *** 
Воскресенье 18 августа 2024  23:45:10 +0300 (0:00:00.050)       0:00:46.376 *** 
Воскресенье 18 августа 2024  23:45:11 +0300 (0:00:00.130)       0:00:46.506 *** 
Воскресенье 18 августа 2024  23:45:11 +0300 (0:00:00.051)       0:00:46.558 *** 
Воскресенье 18 августа 2024  23:45:11 +0300 (0:00:00.050)       0:00:46.609 *** 
Воскресенье 18 августа 2024  23:45:11 +0300 (0:00:00.052)       0:00:46.662 *** 
Воскресенье 18 августа 2024  23:45:11 +0300 (0:00:00.053)       0:00:46.715 *** 
Воскресенье 18 августа 2024  23:45:11 +0300 (0:00:00.050)       0:00:46.766 *** 
Воскресенье 18 августа 2024  23:45:11 +0300 (0:00:00.049)       0:00:46.815 *** 
Воскресенье 18 августа 2024  23:45:11 +0300 (0:00:00.054)       0:00:46.869 *** 
Воскресенье 18 августа 2024  23:45:11 +0300 (0:00:00.050)       0:00:46.919 *** 
Воскресенье 18 августа 2024  23:45:11 +0300 (0:00:00.056)       0:00:46.976 *** 
Воскресенье 18 августа 2024  23:45:11 +0300 (0:00:00.057)       0:00:47.033 *** 
Воскресенье 18 августа 2024  23:45:11 +0300 (0:00:00.068)       0:00:47.101 *** 
Воскресенье 18 августа 2024  23:45:11 +0300 (0:00:00.082)       0:00:47.183 *** 
Воскресенье 18 августа 2024  23:45:11 +0300 (0:00:00.051)       0:00:47.234 *** 
Воскресенье 18 августа 2024  23:45:11 +0300 (0:00:00.045)       0:00:47.280 *** 
Воскресенье 18 августа 2024  23:45:11 +0300 (0:00:00.052)       0:00:47.332 *** 
Воскресенье 18 августа 2024  23:45:11 +0300 (0:00:00.060)       0:00:47.393 *** 
Воскресенье 18 августа 2024  23:45:12 +0300 (0:00:00.057)       0:00:47.450 *** 
Воскресенье 18 августа 2024  23:45:12 +0300 (0:00:00.060)       0:00:47.511 *** 
Воскресенье 18 августа 2024  23:45:12 +0300 (0:00:00.061)       0:00:47.572 *** 
Воскресенье 18 августа 2024  23:45:12 +0300 (0:00:00.048)       0:00:47.620 *** 
Воскресенье 18 августа 2024  23:45:12 +0300 (0:00:00.058)       0:00:47.679 *** 
Воскресенье 18 августа 2024  23:45:12 +0300 (0:00:00.560)       0:00:48.239 *** 
Воскресенье 18 августа 2024  23:45:12 +0300 (0:00:00.048)       0:00:48.288 *** 
Воскресенье 18 августа 2024  23:45:12 +0300 (0:00:00.063)       0:00:48.352 *** 
Воскресенье 18 августа 2024  23:45:12 +0300 (0:00:00.051)       0:00:48.403 *** 
Воскресенье 18 августа 2024  23:45:13 +0300 (0:00:00.070)       0:00:48.473 *** 
Воскресенье 18 августа 2024  23:45:13 +0300 (0:00:00.055)       0:00:48.529 *** 
Воскресенье 18 августа 2024  23:45:13 +0300 (0:00:00.047)       0:00:48.577 *** 
Воскресенье 18 августа 2024  23:45:13 +0300 (0:00:00.053)       0:00:48.630 *** 
Воскресенье 18 августа 2024  23:45:13 +0300 (0:00:00.046)       0:00:48.676 *** 
Воскресенье 18 августа 2024  23:45:13 +0300 (0:00:00.056)       0:00:48.733 *** 
Воскресенье 18 августа 2024  23:45:13 +0300 (0:00:00.065)       0:00:48.799 *** 
Воскресенье 18 августа 2024  23:45:13 +0300 (0:00:00.067)       0:00:48.867 *** 
Воскресенье 18 августа 2024  23:45:13 +0300 (0:00:00.054)       0:00:48.921 *** 
Воскресенье 18 августа 2024  23:45:13 +0300 (0:00:00.052)       0:00:48.974 *** 
Воскресенье 18 августа 2024  23:45:13 +0300 (0:00:00.046)       0:00:49.020 *** 
Воскресенье 18 августа 2024  23:45:13 +0300 (0:00:00.058)       0:00:49.078 *** 
Воскресенье 18 августа 2024  23:45:13 +0300 (0:00:00.065)       0:00:49.144 *** 
Воскресенье 18 августа 2024  23:45:13 +0300 (0:00:00.047)       0:00:49.191 *** 
Воскресенье 18 августа 2024  23:45:13 +0300 (0:00:00.054)       0:00:49.246 *** 
Воскресенье 18 августа 2024  23:45:13 +0300 (0:00:00.055)       0:00:49.301 *** 
Воскресенье 18 августа 2024  23:45:13 +0300 (0:00:00.053)       0:00:49.355 *** 
Воскресенье 18 августа 2024  23:45:13 +0300 (0:00:00.056)       0:00:49.411 *** 
Воскресенье 18 августа 2024  23:45:14 +0300 (0:00:00.056)       0:00:49.468 *** 
Воскресенье 18 августа 2024  23:45:14 +0300 (0:00:00.053)       0:00:49.521 *** 
Воскресенье 18 августа 2024  23:45:14 +0300 (0:00:00.053)       0:00:49.574 *** 
Воскресенье 18 августа 2024  23:45:14 +0300 (0:00:00.059)       0:00:49.634 *** 
Воскресенье 18 августа 2024  23:45:14 +0300 (0:00:00.048)       0:00:49.682 *** 
Воскресенье 18 августа 2024  23:45:14 +0300 (0:00:00.047)       0:00:49.730 *** 
Воскресенье 18 августа 2024  23:45:14 +0300 (0:00:00.051)       0:00:49.781 *** 
Воскресенье 18 августа 2024  23:45:14 +0300 (0:00:00.143)       0:00:49.925 *** 
Воскресенье 18 августа 2024  23:45:14 +0300 (0:00:00.049)       0:00:49.974 *** 
Воскресенье 18 августа 2024  23:45:14 +0300 (0:00:00.051)       0:00:50.026 *** 
Воскресенье 18 августа 2024  23:45:14 +0300 (0:00:00.057)       0:00:50.083 *** 
Воскресенье 18 августа 2024  23:45:14 +0300 (0:00:00.047)       0:00:50.131 *** 
Воскресенье 18 августа 2024  23:45:14 +0300 (0:00:00.053)       0:00:50.184 *** 
Воскресенье 18 августа 2024  23:45:14 +0300 (0:00:00.052)       0:00:50.237 *** 
Воскресенье 18 августа 2024  23:45:14 +0300 (0:00:00.059)       0:00:50.297 *** 
Воскресенье 18 августа 2024  23:45:14 +0300 (0:00:00.046)       0:00:50.343 *** 
Воскресенье 18 августа 2024  23:45:14 +0300 (0:00:00.046)       0:00:50.390 *** 
Воскресенье 18 августа 2024  23:45:15 +0300 (0:00:00.059)       0:00:50.449 *** 
Воскресенье 18 августа 2024  23:45:15 +0300 (0:00:00.051)       0:00:50.500 *** 
Воскресенье 18 августа 2024  23:45:15 +0300 (0:00:00.047)       0:00:50.547 *** 
Воскресенье 18 августа 2024  23:45:15 +0300 (0:00:00.040)       0:00:50.588 *** 
Воскресенье 18 августа 2024  23:45:15 +0300 (0:00:00.049)       0:00:50.637 *** 
Воскресенье 18 августа 2024  23:45:15 +0300 (0:00:00.049)       0:00:50.687 *** 
Воскресенье 18 августа 2024  23:45:15 +0300 (0:00:00.060)       0:00:50.747 *** 
Воскресенье 18 августа 2024  23:45:15 +0300 (0:00:00.052)       0:00:50.800 *** 
Воскресенье 18 августа 2024  23:45:15 +0300 (0:00:00.056)       0:00:50.856 *** 
Воскресенье 18 августа 2024  23:45:15 +0300 (0:00:00.066)       0:00:50.923 *** 

TASK [container-engine/containerd-common : Containerd-common | check if fedora coreos] *******************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:45:15 +0300 (0:00:00.344)       0:00:51.268 *** 

TASK [container-engine/containerd-common : Containerd-common | set is_ostree] ****************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:45:15 +0300 (0:00:00.067)       0:00:51.335 *** 

TASK [container-engine/containerd-common : Containerd-common | gather os specific variables] *************************************************************************
ok: [master] => (item=/home/serg/DevOps-35-diplom-yc/kubespray/roles/container-engine/containerd/vars/../vars/ubuntu.yml)
ok: [worker-1] => (item=/home/serg/DevOps-35-diplom-yc/kubespray/roles/container-engine/containerd/vars/../vars/ubuntu.yml)
ok: [worker-2] => (item=/home/serg/DevOps-35-diplom-yc/kubespray/roles/container-engine/containerd/vars/../vars/ubuntu.yml)
Воскресенье 18 августа 2024  23:45:16 +0300 (0:00:00.089)       0:00:51.424 *** 

TASK [container-engine/runc : Runc | check if fedora coreos] *********************************************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:45:16 +0300 (0:00:00.338)       0:00:51.763 *** 

TASK [container-engine/runc : Runc | set is_ostree] ******************************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:45:16 +0300 (0:00:00.063)       0:00:51.827 *** 

TASK [container-engine/runc : Runc | Uninstall runc package managed by package manager] ******************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:45:17 +0300 (0:00:01.067)       0:00:52.894 *** 

TASK [container-engine/runc : Runc | Download runc binary] ***********************************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/container-engine/runc/tasks/../../../download/tasks/download_file.yml for master, worker-1, worker-2
Воскресенье 18 августа 2024  23:45:17 +0300 (0:00:00.071)       0:00:52.966 *** 

TASK [container-engine/runc : Prep_download | Set a few facts] *******************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:45:17 +0300 (0:00:00.309)       0:00:53.275 *** 

TASK [container-engine/runc : Download_file | Show url of file to dowload] *******************************************************************************************
ok: [master] => {
    "msg": "https://github.com/opencontainers/runc/releases/download/v1.1.13/runc.amd64"
}
ok: [worker-1] => {
    "msg": "https://github.com/opencontainers/runc/releases/download/v1.1.13/runc.amd64"
}
ok: [worker-2] => {
    "msg": "https://github.com/opencontainers/runc/releases/download/v1.1.13/runc.amd64"
}
Воскресенье 18 августа 2024  23:45:18 +0300 (0:00:00.533)       0:00:53.809 *** 

TASK [container-engine/runc : Download_file | Set pathname of cached file] *******************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:45:18 +0300 (0:00:00.562)       0:00:54.372 *** 

TASK [container-engine/runc : Download_file | Create dest directory on node] *****************************************************************************************
ok: [worker-1]
changed: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:45:20 +0300 (0:00:01.048)       0:00:55.420 *** 
Воскресенье 18 августа 2024  23:45:20 +0300 (0:00:00.026)       0:00:55.447 *** 
Воскресенье 18 августа 2024  23:45:20 +0300 (0:00:00.031)       0:00:55.478 *** 

TASK [container-engine/runc : Download_file | Download item] *********************************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:45:23 +0300 (0:00:02.943)       0:00:58.422 *** 
Воскресенье 18 августа 2024  23:45:23 +0300 (0:00:00.052)       0:00:58.474 *** 
Воскресенье 18 августа 2024  23:45:23 +0300 (0:00:00.049)       0:00:58.524 *** 
Воскресенье 18 августа 2024  23:45:23 +0300 (0:00:00.050)       0:00:58.574 *** 

TASK [container-engine/runc : Download_file | Extract file archives] *************************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/extract_file.yml for master, worker-1, worker-2
Воскресенье 18 августа 2024  23:45:23 +0300 (0:00:00.076)       0:00:58.650 *** 
Воскресенье 18 августа 2024  23:45:23 +0300 (0:00:00.304)       0:00:58.955 *** 

TASK [container-engine/runc : Copy runc binary from download dir] ****************************************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:45:24 +0300 (0:00:00.920)       0:00:59.876 *** 

TASK [container-engine/runc : Runc | Remove orphaned binary] *********************************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:45:24 +0300 (0:00:00.334)       0:01:00.211 *** 

TASK [container-engine/crictl : Install crictl] **********************************************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/container-engine/crictl/tasks/crictl.yml for master, worker-1, worker-2
Воскресенье 18 августа 2024  23:45:24 +0300 (0:00:00.068)       0:01:00.279 *** 

TASK [container-engine/crictl : Crictl | Download crictl] ************************************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/container-engine/crictl/tasks/../../../download/tasks/download_file.yml for master, worker-1, worker-2
Воскресенье 18 августа 2024  23:45:24 +0300 (0:00:00.079)       0:01:00.358 *** 

TASK [container-engine/crictl : Prep_download | Set a few facts] *****************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:45:25 +0300 (0:00:00.320)       0:01:00.679 *** 

TASK [container-engine/crictl : Download_file | Show url of file to dowload] *****************************************************************************************
ok: [master] => {
    "msg": "https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.30.0/crictl-v1.30.0-linux-amd64.tar.gz"
}
ok: [worker-1] => {
    "msg": "https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.30.0/crictl-v1.30.0-linux-amd64.tar.gz"
}
ok: [worker-2] => {
    "msg": "https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.30.0/crictl-v1.30.0-linux-amd64.tar.gz"
}
Воскресенье 18 августа 2024  23:45:25 +0300 (0:00:00.642)       0:01:01.321 *** 

TASK [container-engine/crictl : Download_file | Set pathname of cached file] *****************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:45:26 +0300 (0:00:00.636)       0:01:01.957 *** 

TASK [container-engine/crictl : Download_file | Create dest directory on node] ***************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:45:27 +0300 (0:00:01.138)       0:01:03.096 *** 
Воскресенье 18 августа 2024  23:45:27 +0300 (0:00:00.032)       0:01:03.128 *** 
Воскресенье 18 августа 2024  23:45:27 +0300 (0:00:00.189)       0:01:03.318 *** 

TASK [container-engine/crictl : Download_file | Download item] *******************************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:45:30 +0300 (0:00:02.872)       0:01:06.190 *** 
Воскресенье 18 августа 2024  23:45:30 +0300 (0:00:00.052)       0:01:06.242 *** 
Воскресенье 18 августа 2024  23:45:30 +0300 (0:00:00.052)       0:01:06.295 *** 
Воскресенье 18 августа 2024  23:45:30 +0300 (0:00:00.057)       0:01:06.352 *** 

TASK [container-engine/crictl : Download_file | Extract file archives] ***********************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/extract_file.yml for master, worker-1, worker-2
Воскресенье 18 августа 2024  23:45:31 +0300 (0:00:00.075)       0:01:06.428 *** 

TASK [container-engine/crictl : Extract_file | Unpacking archive] ****************************************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:45:34 +0300 (0:00:03.567)       0:01:09.995 *** 

TASK [container-engine/crictl : Install crictl config] ***************************************************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:45:35 +0300 (0:00:00.762)       0:01:10.758 *** 

TASK [container-engine/crictl : Copy crictl binary from download dir] ************************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:45:36 +0300 (0:00:00.781)       0:01:11.539 *** 

TASK [container-engine/nerdctl : Nerdctl | Download nerdctl] *********************************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/container-engine/nerdctl/tasks/../../../download/tasks/download_file.yml for master, worker-1, worker-2
Воскресенье 18 августа 2024  23:45:36 +0300 (0:00:00.068)       0:01:11.608 *** 

TASK [container-engine/nerdctl : Prep_download | Set a few facts] ****************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:45:36 +0300 (0:00:00.312)       0:01:11.921 *** 

TASK [container-engine/nerdctl : Download_file | Show url of file to dowload] ****************************************************************************************
ok: [master] => {
    "msg": "https://github.com/containerd/nerdctl/releases/download/v1.7.4/nerdctl-1.7.4-linux-amd64.tar.gz"
}
ok: [worker-1] => {
    "msg": "https://github.com/containerd/nerdctl/releases/download/v1.7.4/nerdctl-1.7.4-linux-amd64.tar.gz"
}
ok: [worker-2] => {
    "msg": "https://github.com/containerd/nerdctl/releases/download/v1.7.4/nerdctl-1.7.4-linux-amd64.tar.gz"
}
Воскресенье 18 августа 2024  23:45:37 +0300 (0:00:00.541)       0:01:12.463 *** 

TASK [container-engine/nerdctl : Download_file | Set pathname of cached file] ****************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:45:37 +0300 (0:00:00.537)       0:01:13.000 *** 

TASK [container-engine/nerdctl : Download_file | Create dest directory on node] **************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:45:38 +0300 (0:00:01.067)       0:01:14.068 *** 
Воскресенье 18 августа 2024  23:45:38 +0300 (0:00:00.027)       0:01:14.095 *** 
Воскресенье 18 августа 2024  23:45:38 +0300 (0:00:00.031)       0:01:14.127 *** 

TASK [container-engine/nerdctl : Download_file | Download item] ******************************************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:45:41 +0300 (0:00:02.856)       0:01:16.983 *** 
Воскресенье 18 августа 2024  23:45:41 +0300 (0:00:00.052)       0:01:17.036 *** 
Воскресенье 18 августа 2024  23:45:41 +0300 (0:00:00.050)       0:01:17.087 *** 
Воскресенье 18 августа 2024  23:45:41 +0300 (0:00:00.050)       0:01:17.137 *** 

TASK [container-engine/nerdctl : Download_file | Extract file archives] **********************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/extract_file.yml for master, worker-1, worker-2
Воскресенье 18 августа 2024  23:45:41 +0300 (0:00:00.075)       0:01:17.212 *** 

TASK [container-engine/nerdctl : Extract_file | Unpacking archive] ***************************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:45:44 +0300 (0:00:02.761)       0:01:19.973 *** 

TASK [container-engine/nerdctl : Nerdctl | Copy nerdctl binary from download dir] ************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:45:45 +0300 (0:00:00.605)       0:01:20.579 *** 

TASK [container-engine/nerdctl : Nerdctl | Create configuration dir] *************************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:45:45 +0300 (0:00:00.319)       0:01:20.899 *** 

TASK [container-engine/nerdctl : Nerdctl | Install nerdctl configuration] ********************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:45:46 +0300 (0:00:00.712)       0:01:21.611 *** 
Воскресенье 18 августа 2024  23:45:46 +0300 (0:00:00.064)       0:01:21.676 *** 

TASK [container-engine/containerd : Containerd | Remove any package manager controlled containerd package] ***********************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:45:47 +0300 (0:00:01.153)       0:01:22.830 *** 
Воскресенье 18 августа 2024  23:45:47 +0300 (0:00:00.048)       0:01:22.879 *** 

TASK [container-engine/containerd : Containerd | Remove containerd repository] ***************************************************************************************
ok: [worker-1] => (item=deb https://download.docker.com/linux/ubuntu jammy stable
)
ok: [worker-2] => (item=deb https://download.docker.com/linux/ubuntu jammy stable
)
ok: [master] => (item=deb https://download.docker.com/linux/ubuntu jammy stable
)
Воскресенье 18 августа 2024  23:45:48 +0300 (0:00:00.791)       0:01:23.670 *** 

TASK [container-engine/containerd : Containerd | Download containerd] ************************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/container-engine/containerd/tasks/../../../download/tasks/download_file.yml for master, worker-1, worker-2
Воскресенье 18 августа 2024  23:45:48 +0300 (0:00:00.074)       0:01:23.744 *** 

TASK [container-engine/containerd : Prep_download | Set a few facts] *************************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:45:48 +0300 (0:00:00.320)       0:01:24.065 *** 

TASK [container-engine/containerd : Download_file | Show url of file to dowload] *************************************************************************************
ok: [master] => {
    "msg": "https://github.com/containerd/containerd/releases/download/v1.7.20/containerd-1.7.20-linux-amd64.tar.gz"
}
ok: [worker-1] => {
    "msg": "https://github.com/containerd/containerd/releases/download/v1.7.20/containerd-1.7.20-linux-amd64.tar.gz"
}
ok: [worker-2] => {
    "msg": "https://github.com/containerd/containerd/releases/download/v1.7.20/containerd-1.7.20-linux-amd64.tar.gz"
}
Воскресенье 18 августа 2024  23:45:49 +0300 (0:00:00.545)       0:01:24.610 *** 

TASK [container-engine/containerd : Download_file | Set pathname of cached file] *************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:45:49 +0300 (0:00:00.532)       0:01:25.143 *** 

TASK [container-engine/containerd : Download_file | Create dest directory on node] ***********************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:45:50 +0300 (0:00:01.063)       0:01:26.206 *** 
Воскресенье 18 августа 2024  23:45:50 +0300 (0:00:00.029)       0:01:26.236 *** 
Воскресенье 18 августа 2024  23:45:50 +0300 (0:00:00.033)       0:01:26.270 *** 

TASK [container-engine/containerd : Download_file | Download item] ***************************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:45:53 +0300 (0:00:02.975)       0:01:29.246 *** 
Воскресенье 18 августа 2024  23:45:53 +0300 (0:00:00.049)       0:01:29.296 *** 
Воскресенье 18 августа 2024  23:45:53 +0300 (0:00:00.049)       0:01:29.346 *** 
Воскресенье 18 августа 2024  23:45:53 +0300 (0:00:00.054)       0:01:29.400 *** 

TASK [container-engine/containerd : Download_file | Extract file archives] *******************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/extract_file.yml for master, worker-1, worker-2
Воскресенье 18 августа 2024  23:45:54 +0300 (0:00:00.071)       0:01:29.472 *** 
Воскресенье 18 августа 2024  23:45:54 +0300 (0:00:00.306)       0:01:29.779 *** 

TASK [container-engine/containerd : Containerd | Unpack containerd archive] ******************************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:45:58 +0300 (0:00:03.952)       0:01:33.731 *** 

TASK [container-engine/containerd : Containerd | Remove orphaned binary] *********************************************************************************************
ok: [worker-1] => (item=containerd)
ok: [worker-2] => (item=containerd)
ok: [master] => (item=containerd)
ok: [worker-1] => (item=containerd-shim)
ok: [worker-2] => (item=containerd-shim)
ok: [master] => (item=containerd-shim)
ok: [worker-1] => (item=containerd-shim-runc-v1)
ok: [worker-2] => (item=containerd-shim-runc-v1)
ok: [master] => (item=containerd-shim-runc-v1)
ok: [worker-1] => (item=containerd-shim-runc-v2)
ok: [worker-2] => (item=containerd-shim-runc-v2)
ok: [master] => (item=containerd-shim-runc-v2)
ok: [worker-1] => (item=ctr)
ok: [worker-2] => (item=ctr)
ok: [master] => (item=ctr)
Воскресенье 18 августа 2024  23:45:59 +0300 (0:00:01.515)       0:01:35.247 *** 

TASK [container-engine/containerd : Containerd | Generate systemd service for containerd] ****************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:46:00 +0300 (0:00:00.717)       0:01:35.964 *** 

TASK [container-engine/containerd : Containerd | Ensure containerd directories exist] ********************************************************************************
ok: [worker-1] => (item=/etc/systemd/system/containerd.service.d)
ok: [master] => (item=/etc/systemd/system/containerd.service.d)
ok: [worker-2] => (item=/etc/systemd/system/containerd.service.d)
ok: [worker-1] => (item=/etc/containerd)
ok: [worker-2] => (item=/etc/containerd)
ok: [master] => (item=/etc/containerd)
ok: [worker-1] => (item=/var/lib/containerd)
ok: [worker-2] => (item=/var/lib/containerd)
ok: [master] => (item=/var/lib/containerd)
ok: [worker-1] => (item=/run/containerd)
ok: [worker-2] => (item=/run/containerd)
ok: [master] => (item=/run/containerd)
Воскресенье 18 августа 2024  23:46:01 +0300 (0:00:01.200)       0:01:37.165 *** 
Воскресенье 18 августа 2024  23:46:01 +0300 (0:00:00.059)       0:01:37.225 *** 

TASK [container-engine/containerd : Containerd | Generate default base_runtime_spec] *********************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:46:02 +0300 (0:00:00.339)       0:01:37.564 *** 

TASK [container-engine/containerd : Containerd | Store generated default base_runtime_spec] **************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:02 +0300 (0:00:00.226)       0:01:37.791 *** 

TASK [container-engine/containerd : Containerd | Write base_runtime_specs] *******************************************************************************************
ok: [worker-1] => (item={'key': 'cri-base.json', 'value': {'ociVersion': '1.1.0', 'process': {'user': {'uid': 0, 'gid': 0}, 'cwd': '/', 'capabilities': {'bounding': ['CAP_CHOWN', 'CAP_DAC_OVERRIDE', 'CAP_FSETID', 'CAP_FOWNER', 'CAP_MKNOD', 'CAP_NET_RAW', 'CAP_SETGID', 'CAP_SETUID', 'CAP_SETFCAP', 'CAP_SETPCAP', 'CAP_NET_BIND_SERVICE', 'CAP_SYS_CHROOT', 'CAP_KILL', 'CAP_AUDIT_WRITE'], 'effective': ['CAP_CHOWN', 'CAP_DAC_OVERRIDE', 'CAP_FSETID', 'CAP_FOWNER', 'CAP_MKNOD', 'CAP_NET_RAW', 'CAP_SETGID', 'CAP_SETUID', 'CAP_SETFCAP', 'CAP_SETPCAP', 'CAP_NET_BIND_SERVICE', 'CAP_SYS_CHROOT', 'CAP_KILL', 'CAP_AUDIT_WRITE'], 'permitted': ['CAP_CHOWN', 'CAP_DAC_OVERRIDE', 'CAP_FSETID', 'CAP_FOWNER', 'CAP_MKNOD', 'CAP_NET_RAW', 'CAP_SETGID', 'CAP_SETUID', 'CAP_SETFCAP', 'CAP_SETPCAP', 'CAP_NET_BIND_SERVICE', 'CAP_SYS_CHROOT', 'CAP_KILL', 'CAP_AUDIT_WRITE']}, 'rlimits': [{'type': 'RLIMIT_NOFILE', 'hard': 65535, 'soft': 65535}], 'noNewPrivileges': True}, 'root': {'path': 'rootfs'}, 'mounts': [{'destination': '/proc', 'type': 'proc', 'source': 'proc', 'options': ['nosuid', 'noexec', 'nodev']}, {'destination': '/dev', 'type': 'tmpfs', 'source': 'tmpfs', 'options': ['nosuid', 'strictatime', 'mode=755', 'size=65536k']}, {'destination': '/dev/pts', 'type': 'devpts', 'source': 'devpts', 'options': ['nosuid', 'noexec', 'newinstance', 'ptmxmode=0666', 'mode=0620', 'gid=5']}, {'destination': '/dev/shm', 'type': 'tmpfs', 'source': 'shm', 'options': ['nosuid', 'noexec', 'nodev', 'mode=1777', 'size=65536k']}, {'destination': '/dev/mqueue', 'type': 'mqueue', 'source': 'mqueue', 'options': ['nosuid', 'noexec', 'nodev']}, {'destination': '/sys', 'type': 'sysfs', 'source': 'sysfs', 'options': ['nosuid', 'noexec', 'nodev', 'ro']}, {'destination': '/run', 'type': 'tmpfs', 'source': 'tmpfs', 'options': ['nosuid', 'strictatime', 'mode=755', 'size=65536k']}], 'linux': {'resources': {'devices': [{'allow': False, 'access': 'rwm'}]}, 'cgroupsPath': '/default', 'namespaces': [{'type': 'pid'}, {'type': 'ipc'}, {'type': 'uts'}, {'type': 'mount'}, {'type': 'network'}], 'maskedPaths': ['/proc/acpi', '/proc/asound', '/proc/kcore', '/proc/keys', '/proc/latency_stats', '/proc/timer_list', '/proc/timer_stats', '/proc/sched_debug', '/sys/firmware', '/sys/devices/virtual/powercap', '/proc/scsi'], 'readonlyPaths': ['/proc/bus', '/proc/fs', '/proc/irq', '/proc/sys', '/proc/sysrq-trigger']}}})
ok: [worker-2] => (item={'key': 'cri-base.json', 'value': {'ociVersion': '1.1.0', 'process': {'user': {'uid': 0, 'gid': 0}, 'cwd': '/', 'capabilities': {'bounding': ['CAP_CHOWN', 'CAP_DAC_OVERRIDE', 'CAP_FSETID', 'CAP_FOWNER', 'CAP_MKNOD', 'CAP_NET_RAW', 'CAP_SETGID', 'CAP_SETUID', 'CAP_SETFCAP', 'CAP_SETPCAP', 'CAP_NET_BIND_SERVICE', 'CAP_SYS_CHROOT', 'CAP_KILL', 'CAP_AUDIT_WRITE'], 'effective': ['CAP_CHOWN', 'CAP_DAC_OVERRIDE', 'CAP_FSETID', 'CAP_FOWNER', 'CAP_MKNOD', 'CAP_NET_RAW', 'CAP_SETGID', 'CAP_SETUID', 'CAP_SETFCAP', 'CAP_SETPCAP', 'CAP_NET_BIND_SERVICE', 'CAP_SYS_CHROOT', 'CAP_KILL', 'CAP_AUDIT_WRITE'], 'permitted': ['CAP_CHOWN', 'CAP_DAC_OVERRIDE', 'CAP_FSETID', 'CAP_FOWNER', 'CAP_MKNOD', 'CAP_NET_RAW', 'CAP_SETGID', 'CAP_SETUID', 'CAP_SETFCAP', 'CAP_SETPCAP', 'CAP_NET_BIND_SERVICE', 'CAP_SYS_CHROOT', 'CAP_KILL', 'CAP_AUDIT_WRITE']}, 'rlimits': [{'type': 'RLIMIT_NOFILE', 'hard': 65535, 'soft': 65535}], 'noNewPrivileges': True}, 'root': {'path': 'rootfs'}, 'mounts': [{'destination': '/proc', 'type': 'proc', 'source': 'proc', 'options': ['nosuid', 'noexec', 'nodev']}, {'destination': '/dev', 'type': 'tmpfs', 'source': 'tmpfs', 'options': ['nosuid', 'strictatime', 'mode=755', 'size=65536k']}, {'destination': '/dev/pts', 'type': 'devpts', 'source': 'devpts', 'options': ['nosuid', 'noexec', 'newinstance', 'ptmxmode=0666', 'mode=0620', 'gid=5']}, {'destination': '/dev/shm', 'type': 'tmpfs', 'source': 'shm', 'options': ['nosuid', 'noexec', 'nodev', 'mode=1777', 'size=65536k']}, {'destination': '/dev/mqueue', 'type': 'mqueue', 'source': 'mqueue', 'options': ['nosuid', 'noexec', 'nodev']}, {'destination': '/sys', 'type': 'sysfs', 'source': 'sysfs', 'options': ['nosuid', 'noexec', 'nodev', 'ro']}, {'destination': '/run', 'type': 'tmpfs', 'source': 'tmpfs', 'options': ['nosuid', 'strictatime', 'mode=755', 'size=65536k']}], 'linux': {'resources': {'devices': [{'allow': False, 'access': 'rwm'}]}, 'cgroupsPath': '/default', 'namespaces': [{'type': 'pid'}, {'type': 'ipc'}, {'type': 'uts'}, {'type': 'mount'}, {'type': 'network'}], 'maskedPaths': ['/proc/acpi', '/proc/asound', '/proc/kcore', '/proc/keys', '/proc/latency_stats', '/proc/timer_list', '/proc/timer_stats', '/proc/sched_debug', '/sys/firmware', '/sys/devices/virtual/powercap', '/proc/scsi'], 'readonlyPaths': ['/proc/bus', '/proc/fs', '/proc/irq', '/proc/sys', '/proc/sysrq-trigger']}}})
ok: [master] => (item={'key': 'cri-base.json', 'value': {'ociVersion': '1.1.0', 'process': {'user': {'uid': 0, 'gid': 0}, 'cwd': '/', 'capabilities': {'bounding': ['CAP_CHOWN', 'CAP_DAC_OVERRIDE', 'CAP_FSETID', 'CAP_FOWNER', 'CAP_MKNOD', 'CAP_NET_RAW', 'CAP_SETGID', 'CAP_SETUID', 'CAP_SETFCAP', 'CAP_SETPCAP', 'CAP_NET_BIND_SERVICE', 'CAP_SYS_CHROOT', 'CAP_KILL', 'CAP_AUDIT_WRITE'], 'effective': ['CAP_CHOWN', 'CAP_DAC_OVERRIDE', 'CAP_FSETID', 'CAP_FOWNER', 'CAP_MKNOD', 'CAP_NET_RAW', 'CAP_SETGID', 'CAP_SETUID', 'CAP_SETFCAP', 'CAP_SETPCAP', 'CAP_NET_BIND_SERVICE', 'CAP_SYS_CHROOT', 'CAP_KILL', 'CAP_AUDIT_WRITE'], 'permitted': ['CAP_CHOWN', 'CAP_DAC_OVERRIDE', 'CAP_FSETID', 'CAP_FOWNER', 'CAP_MKNOD', 'CAP_NET_RAW', 'CAP_SETGID', 'CAP_SETUID', 'CAP_SETFCAP', 'CAP_SETPCAP', 'CAP_NET_BIND_SERVICE', 'CAP_SYS_CHROOT', 'CAP_KILL', 'CAP_AUDIT_WRITE']}, 'rlimits': [{'type': 'RLIMIT_NOFILE', 'hard': 65535, 'soft': 65535}], 'noNewPrivileges': True}, 'root': {'path': 'rootfs'}, 'mounts': [{'destination': '/proc', 'type': 'proc', 'source': 'proc', 'options': ['nosuid', 'noexec', 'nodev']}, {'destination': '/dev', 'type': 'tmpfs', 'source': 'tmpfs', 'options': ['nosuid', 'strictatime', 'mode=755', 'size=65536k']}, {'destination': '/dev/pts', 'type': 'devpts', 'source': 'devpts', 'options': ['nosuid', 'noexec', 'newinstance', 'ptmxmode=0666', 'mode=0620', 'gid=5']}, {'destination': '/dev/shm', 'type': 'tmpfs', 'source': 'shm', 'options': ['nosuid', 'noexec', 'nodev', 'mode=1777', 'size=65536k']}, {'destination': '/dev/mqueue', 'type': 'mqueue', 'source': 'mqueue', 'options': ['nosuid', 'noexec', 'nodev']}, {'destination': '/sys', 'type': 'sysfs', 'source': 'sysfs', 'options': ['nosuid', 'noexec', 'nodev', 'ro']}, {'destination': '/run', 'type': 'tmpfs', 'source': 'tmpfs', 'options': ['nosuid', 'strictatime', 'mode=755', 'size=65536k']}], 'linux': {'resources': {'devices': [{'allow': False, 'access': 'rwm'}]}, 'cgroupsPath': '/default', 'namespaces': [{'type': 'pid'}, {'type': 'ipc'}, {'type': 'uts'}, {'type': 'mount'}, {'type': 'network'}], 'maskedPaths': ['/proc/acpi', '/proc/asound', '/proc/kcore', '/proc/keys', '/proc/latency_stats', '/proc/timer_list', '/proc/timer_stats', '/proc/sched_debug', '/sys/firmware', '/sys/devices/virtual/powercap', '/proc/scsi'], 'readonlyPaths': ['/proc/bus', '/proc/fs', '/proc/irq', '/proc/sys', '/proc/sysrq-trigger']}}})
Воскресенье 18 августа 2024  23:46:03 +0300 (0:00:00.731)       0:01:38.523 *** 

TASK [container-engine/containerd : Containerd | Copy containerd config file] ****************************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:46:03 +0300 (0:00:00.746)       0:01:39.269 *** 

TASK [container-engine/containerd : Containerd | Create registry directories] ****************************************************************************************
ok: [worker-1] => (item={'prefix': 'docker.io', 'mirrors': [{'host': 'https://registry-1.docker.io', 'capabilities': ['pull', 'resolve'], 'skip_verify': False}]})
ok: [master] => (item={'prefix': 'docker.io', 'mirrors': [{'host': 'https://registry-1.docker.io', 'capabilities': ['pull', 'resolve'], 'skip_verify': False}]})
ok: [worker-2] => (item={'prefix': 'docker.io', 'mirrors': [{'host': 'https://registry-1.docker.io', 'capabilities': ['pull', 'resolve'], 'skip_verify': False}]})
Воскресенье 18 августа 2024  23:46:04 +0300 (0:00:00.326)       0:01:39.596 *** 

TASK [container-engine/containerd : Containerd | Write hosts.toml file] **********************************************************************************************
ok: [worker-1] => (item={'prefix': 'docker.io', 'mirrors': [{'host': 'https://registry-1.docker.io', 'capabilities': ['pull', 'resolve'], 'skip_verify': False}]})
ok: [master] => (item={'prefix': 'docker.io', 'mirrors': [{'host': 'https://registry-1.docker.io', 'capabilities': ['pull', 'resolve'], 'skip_verify': False}]})
ok: [worker-2] => (item={'prefix': 'docker.io', 'mirrors': [{'host': 'https://registry-1.docker.io', 'capabilities': ['pull', 'resolve'], 'skip_verify': False}]})
Воскресенье 18 августа 2024  23:46:04 +0300 (0:00:00.709)       0:01:40.305 *** 
Воскресенье 18 августа 2024  23:46:04 +0300 (0:00:00.011)       0:01:40.316 *** 
Воскресенье 18 августа 2024  23:46:04 +0300 (0:00:00.009)       0:01:40.326 *** 
Воскресенье 18 августа 2024  23:46:04 +0300 (0:00:00.009)       0:01:40.336 *** 

TASK [container-engine/containerd : Containerd | Ensure containerd is started and enabled] ***************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:46:05 +0300 (0:00:00.869)       0:01:41.205 *** 
Воскресенье 18 августа 2024  23:46:05 +0300 (0:00:00.047)       0:01:41.253 *** 
Воскресенье 18 августа 2024  23:46:05 +0300 (0:00:00.051)       0:01:41.305 *** 
Воскресенье 18 августа 2024  23:46:05 +0300 (0:00:00.086)       0:01:41.392 *** 
Воскресенье 18 августа 2024  23:46:06 +0300 (0:00:00.056)       0:01:41.448 *** 
Воскресенье 18 августа 2024  23:46:06 +0300 (0:00:00.055)       0:01:41.503 *** 
Воскресенье 18 августа 2024  23:46:06 +0300 (0:00:00.047)       0:01:41.551 *** 
Воскресенье 18 августа 2024  23:46:06 +0300 (0:00:00.047)       0:01:41.598 *** 
Воскресенье 18 августа 2024  23:46:06 +0300 (0:00:00.045)       0:01:41.644 *** 
Воскресенье 18 августа 2024  23:46:06 +0300 (0:00:00.065)       0:01:41.709 *** 
Воскресенье 18 августа 2024  23:46:06 +0300 (0:00:00.046)       0:01:41.756 *** 
Воскресенье 18 августа 2024  23:46:06 +0300 (0:00:00.049)       0:01:41.805 *** 
Воскресенье 18 августа 2024  23:46:06 +0300 (0:00:00.072)       0:01:41.878 *** 
Воскресенье 18 августа 2024  23:46:06 +0300 (0:00:00.046)       0:01:41.924 *** 
Воскресенье 18 августа 2024  23:46:06 +0300 (0:00:00.046)       0:01:41.970 *** 
Воскресенье 18 августа 2024  23:46:06 +0300 (0:00:00.052)       0:01:42.023 *** 
Воскресенье 18 августа 2024  23:46:06 +0300 (0:00:00.047)       0:01:42.071 *** 
Воскресенье 18 августа 2024  23:46:06 +0300 (0:00:00.048)       0:01:42.120 *** 
Воскресенье 18 августа 2024  23:46:06 +0300 (0:00:00.046)       0:01:42.167 *** 
Воскресенье 18 августа 2024  23:46:06 +0300 (0:00:00.056)       0:01:42.223 *** 
Воскресенье 18 августа 2024  23:46:06 +0300 (0:00:00.047)       0:01:42.271 *** 
Воскресенье 18 августа 2024  23:46:06 +0300 (0:00:00.050)       0:01:42.322 *** 
Воскресенье 18 августа 2024  23:46:06 +0300 (0:00:00.050)       0:01:42.372 *** 
Воскресенье 18 августа 2024  23:46:07 +0300 (0:00:00.048)       0:01:42.420 *** 
Воскресенье 18 августа 2024  23:46:07 +0300 (0:00:00.060)       0:01:42.480 *** 
Воскресенье 18 августа 2024  23:46:07 +0300 (0:00:00.045)       0:01:42.526 *** 
Воскресенье 18 августа 2024  23:46:07 +0300 (0:00:00.062)       0:01:42.589 *** 
Воскресенье 18 августа 2024  23:46:07 +0300 (0:00:00.047)       0:01:42.636 *** 
Воскресенье 18 августа 2024  23:46:07 +0300 (0:00:00.011)       0:01:42.648 *** 
Воскресенье 18 августа 2024  23:46:07 +0300 (0:00:00.009)       0:01:42.657 *** 
Воскресенье 18 августа 2024  23:46:07 +0300 (0:00:00.009)       0:01:42.667 *** 
Воскресенье 18 августа 2024  23:46:07 +0300 (0:00:00.047)       0:01:42.714 *** 
Воскресенье 18 августа 2024  23:46:07 +0300 (0:00:00.047)       0:01:42.762 *** 
Воскресенье 18 августа 2024  23:46:07 +0300 (0:00:00.048)       0:01:42.810 *** 
Воскресенье 18 августа 2024  23:46:07 +0300 (0:00:00.045)       0:01:42.856 *** 
Воскресенье 18 августа 2024  23:46:07 +0300 (0:00:00.052)       0:01:42.909 *** 
Воскресенье 18 августа 2024  23:46:07 +0300 (0:00:00.048)       0:01:42.958 *** 
Воскресенье 18 августа 2024  23:46:07 +0300 (0:00:00.047)       0:01:43.005 *** 
Воскресенье 18 августа 2024  23:46:07 +0300 (0:00:00.050)       0:01:43.055 *** 
Воскресенье 18 августа 2024  23:46:07 +0300 (0:00:00.048)       0:01:43.104 *** 
Воскресенье 18 августа 2024  23:46:07 +0300 (0:00:00.011)       0:01:43.115 *** 
Воскресенье 18 августа 2024  23:46:07 +0300 (0:00:00.009)       0:01:43.125 *** 
Воскресенье 18 августа 2024  23:46:07 +0300 (0:00:00.009)       0:01:43.134 *** 
Воскресенье 18 августа 2024  23:46:07 +0300 (0:00:00.066)       0:01:43.201 *** 
Воскресенье 18 августа 2024  23:46:07 +0300 (0:00:00.050)       0:01:43.251 *** 
Воскресенье 18 августа 2024  23:46:07 +0300 (0:00:00.046)       0:01:43.298 *** 
Воскресенье 18 августа 2024  23:46:07 +0300 (0:00:00.061)       0:01:43.360 *** 
Воскресенье 18 августа 2024  23:46:07 +0300 (0:00:00.011)       0:01:43.371 *** 
Воскресенье 18 августа 2024  23:46:07 +0300 (0:00:00.010)       0:01:43.382 *** 
Воскресенье 18 августа 2024  23:46:08 +0300 (0:00:00.036)       0:01:43.418 *** 

TASK [download : Prep_download | Set a few facts] ********************************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:08 +0300 (0:00:00.064)       0:01:43.482 *** 
Воскресенье 18 августа 2024  23:46:08 +0300 (0:00:00.033)       0:01:43.516 *** 
Воскресенье 18 августа 2024  23:46:08 +0300 (0:00:00.035)       0:01:43.552 *** 
Воскресенье 18 августа 2024  23:46:08 +0300 (0:00:00.058)       0:01:43.610 *** 
Воскресенье 18 августа 2024  23:46:08 +0300 (0:00:00.215)       0:01:43.825 *** 

TASK [download : Prep_download | Register docker images info] ********************************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:09 +0300 (0:00:00.846)       0:01:44.672 *** 

TASK [download : Prep_download | Create staging directory on remote node] ********************************************************************************************
changed: [worker-1]
changed: [master]
changed: [worker-2]
Воскресенье 18 августа 2024  23:46:09 +0300 (0:00:00.343)       0:01:45.016 *** 
Воскресенье 18 августа 2024  23:46:09 +0300 (0:00:00.034)       0:01:45.050 *** 

TASK [download : Download | Get kubeadm binary and list of required images] ******************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/prep_kubeadm_images.yml for master
Воскресенье 18 августа 2024  23:46:09 +0300 (0:00:00.072)       0:01:45.123 *** 
Воскресенье 18 августа 2024  23:46:09 +0300 (0:00:00.255)       0:01:45.378 *** 

TASK [download : Prep_kubeadm_images | Download kubeadm binary] ******************************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/download_file.yml for master
Воскресенье 18 августа 2024  23:46:10 +0300 (0:00:00.291)       0:01:45.670 *** 

TASK [download : Prep_download | Set a few facts] ********************************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:46:10 +0300 (0:00:00.287)       0:01:45.958 *** 

TASK [download : Download_file | Show url of file to dowload] ********************************************************************************************************
ok: [master] => {
    "msg": "https://dl.k8s.io/release/v1.30.3/bin/linux/amd64/kubeadm"
}
Воскресенье 18 августа 2024  23:46:11 +0300 (0:00:00.527)       0:01:46.485 *** 

TASK [download : Download_file | Set pathname of cached file] ********************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:46:11 +0300 (0:00:00.534)       0:01:47.019 *** 

TASK [download : Download_file | Create dest directory on node] ******************************************************************************************************
changed: [master]
Воскресенье 18 августа 2024  23:46:12 +0300 (0:00:01.061)       0:01:48.081 *** 
Воскресенье 18 августа 2024  23:46:12 +0300 (0:00:00.024)       0:01:48.105 *** 
Воскресенье 18 августа 2024  23:46:12 +0300 (0:00:00.031)       0:01:48.137 *** 

TASK [download : Download_file | Download item] **********************************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:46:15 +0300 (0:00:02.962)       0:01:51.100 *** 
Воскресенье 18 августа 2024  23:46:15 +0300 (0:00:00.022)       0:01:51.122 *** 
Воскресенье 18 августа 2024  23:46:15 +0300 (0:00:00.024)       0:01:51.147 *** 
Воскресенье 18 августа 2024  23:46:15 +0300 (0:00:00.028)       0:01:51.176 *** 

TASK [download : Download_file | Extract file archives] **************************************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/extract_file.yml for master
Воскресенье 18 августа 2024  23:46:15 +0300 (0:00:00.031)       0:01:51.208 *** 
Воскресенье 18 августа 2024  23:46:16 +0300 (0:00:00.271)       0:01:51.479 *** 

TASK [download : Prep_kubeadm_images | Create kubeadm config] ********************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:46:16 +0300 (0:00:00.702)       0:01:52.181 *** 

TASK [download : Prep_kubeadm_images | Copy kubeadm binary from download dir to system path] *************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:46:17 +0300 (0:00:00.948)       0:01:53.129 *** 

TASK [download : Prep_kubeadm_images | Set kubeadm binary permissions] ***********************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:46:17 +0300 (0:00:00.276)       0:01:53.406 *** 

TASK [download : Prep_kubeadm_images | Generate list of required images] *********************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:46:18 +0300 (0:00:00.345)       0:01:53.752 *** 

TASK [download : Prep_kubeadm_images | Parse list of images] *********************************************************************************************************
ok: [master] => (item=registry.k8s.io/kube-apiserver:v1.30.3)
ok: [master] => (item=registry.k8s.io/kube-controller-manager:v1.30.3)
ok: [master] => (item=registry.k8s.io/kube-scheduler:v1.30.3)
ok: [master] => (item=registry.k8s.io/kube-proxy:v1.30.3)
Воскресенье 18 августа 2024  23:46:18 +0300 (0:00:00.061)       0:01:53.814 *** 

TASK [download : Prep_kubeadm_images | Convert list of images to dict for later use] *********************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:46:18 +0300 (0:00:00.038)       0:01:53.852 *** 

TASK [download : Download | Download files / images] *****************************************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/download_file.yml for master => (item={'key': 'etcd', 'value': {'container': False, 'file': True, 'enabled': True, 'version': 'v3.5.12', 'dest': '/tmp/releases/etcd-v3.5.12-linux-amd64.tar.gz', 'repo': 'quay.io/coreos/etcd', 'tag': 'v3.5.12', 'sha256': 'f2ff0cb43ce119f55a85012255609b61c64263baea83aa7c8e6846c0938adca5', 'url': 'https://github.com/etcd-io/etcd/releases/download/v3.5.12/etcd-v3.5.12-linux-amd64.tar.gz', 'unarchive': True, 'owner': 'root', 'mode': '0755', 'groups': ['etcd']}})
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/download_file.yml for master, worker-1, worker-2 => (item={'key': 'cni', 'value': {'enabled': True, 'file': True, 'version': 'v1.4.0', 'dest': '/tmp/releases/cni-plugins-linux-amd64-v1.4.0.tgz', 'sha256': 'c2485ddb3ffc176578ae30ae58137f0b88e50f7c7f2af7d53a569276b2949a33', 'url': 'https://github.com/containernetworking/plugins/releases/download/v1.4.0/cni-plugins-linux-amd64-v1.4.0.tgz', 'unarchive': False, 'owner': 'root', 'mode': '0755', 'groups': ['k8s_cluster']}})
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/download_file.yml for master, worker-1, worker-2 => (item={'key': 'kubeadm', 'value': {'enabled': True, 'file': True, 'version': 'v1.30.3', 'dest': '/tmp/releases/kubeadm-v1.30.3-amd64', 'sha256': 'bb78c2a27027278ee644d523f583ed7fdba48b4fbf31e3cfb0e309b6457dda69', 'url': 'https://dl.k8s.io/release/v1.30.3/bin/linux/amd64/kubeadm', 'unarchive': False, 'owner': 'root', 'mode': '0755', 'groups': ['k8s_cluster']}})
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/download_file.yml for master, worker-1, worker-2 => (item={'key': 'kubelet', 'value': {'enabled': True, 'file': True, 'version': 'v1.30.3', 'dest': '/tmp/releases/kubelet-v1.30.3-amd64', 'sha256': '9a37ddd5ea026639b7d85e98fa742e392df7aa5ec917bed0711a451613de3c1c', 'url': 'https://dl.k8s.io/release/v1.30.3/bin/linux/amd64/kubelet', 'unarchive': False, 'owner': 'root', 'mode': '0755', 'groups': ['k8s_cluster']}})
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/download_file.yml for master => (item={'key': 'kubectl', 'value': {'enabled': True, 'file': True, 'version': 'v1.30.3', 'dest': '/tmp/releases/kubectl-v1.30.3-amd64', 'sha256': 'abd83816bd236b266c3643e6c852b446f068fe260f3296af1a25b550854ec7e5', 'url': 'https://dl.k8s.io/release/v1.30.3/bin/linux/amd64/kubectl', 'unarchive': False, 'owner': 'root', 'mode': '0755', 'groups': ['kube_control_plane']}})
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/download_file.yml for master, worker-1, worker-2 => (item={'key': 'crictl', 'value': {'file': True, 'enabled': True, 'version': 'v1.30.0', 'dest': '/tmp/releases/crictl-v1.30.0-linux-amd64.tar.gz', 'sha256': '3dd03954565808eaeb3a7ffc0e8cb7886a64a9aa94b2bfdfbdc6e2ed94842e49', 'url': 'https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.30.0/crictl-v1.30.0-linux-amd64.tar.gz', 'unarchive': True, 'owner': 'root', 'mode': '0755', 'groups': ['k8s_cluster']}})
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/download_file.yml for master, worker-1, worker-2 => (item={'key': 'runc', 'value': {'file': True, 'enabled': True, 'version': 'v1.1.13', 'dest': '/tmp/releases/runc-v1.1.13.amd64', 'sha256': 'bcfc299c1ab255e9d045ffaf2e324c0abaf58f599831a7c2c4a80b33f795de94', 'url': 'https://github.com/opencontainers/runc/releases/download/v1.1.13/runc.amd64', 'unarchive': False, 'owner': 'root', 'mode': '0755', 'groups': ['k8s_cluster']}})
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/download_file.yml for master, worker-1, worker-2 => (item={'key': 'containerd', 'value': {'enabled': True, 'file': True, 'version': '1.7.20', 'dest': '/tmp/releases/containerd-1.7.20-linux-amd64.tar.gz', 'sha256': 'e09410787b6f392748959177a84e024424f75d7aff33ea1c5b783f2260edce67', 'url': 'https://github.com/containerd/containerd/releases/download/v1.7.20/containerd-1.7.20-linux-amd64.tar.gz', 'unarchive': False, 'owner': 'root', 'mode': '0755', 'groups': ['k8s_cluster']}})
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/download_file.yml for master, worker-1, worker-2 => (item={'key': 'nerdctl', 'value': {'file': True, 'enabled': True, 'version': '1.7.4', 'dest': '/tmp/releases/nerdctl-1.7.4-linux-amd64.tar.gz', 'sha256': '71aee9d987b7fad0ff2ade50b038ad7e2356324edc02c54045960a3521b3e6a7', 'url': 'https://github.com/containerd/nerdctl/releases/download/v1.7.4/nerdctl-1.7.4-linux-amd64.tar.gz', 'unarchive': True, 'owner': 'root', 'mode': '0755', 'groups': ['k8s_cluster']}})
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/download_file.yml for master, worker-1, worker-2 => (item={'key': 'calicoctl', 'value': {'enabled': True, 'file': True, 'version': 'v3.27.3', 'dest': '/tmp/releases/calicoctl-v3.27.3-amd64', 'sha256': 'e22b8bb41684f8ffb5143b50bf3b2ab76985604d774d397cfb6fb11d8a19f326', 'url': 'https://github.com/projectcalico/calico/releases/download/v3.27.3/calicoctl-linux-amd64', 'unarchive': False, 'owner': 'root', 'mode': '0755', 'groups': ['k8s_cluster']}})
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/download_container.yml for master, worker-1, worker-2 => (item={'key': 'calico_node', 'value': {'enabled': True, 'container': True, 'repo': 'quay.io/calico/node', 'tag': 'v3.27.3', 'sha256': '', 'groups': ['k8s_cluster']}})
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/download_container.yml for master, worker-1, worker-2 => (item={'key': 'calico_cni', 'value': {'enabled': True, 'container': True, 'repo': 'quay.io/calico/cni', 'tag': 'v3.27.3', 'sha256': '', 'groups': ['k8s_cluster']}})
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/download_container.yml for master, worker-1, worker-2 => (item={'key': 'calico_flexvol', 'value': {'enabled': True, 'container': True, 'repo': 'quay.io/calico/pod2daemon-flexvol', 'tag': 'v3.27.3', 'sha256': '', 'groups': ['k8s_cluster']}})
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/download_container.yml for master, worker-1, worker-2 => (item={'key': 'calico_policy', 'value': {'enabled': True, 'container': True, 'repo': 'quay.io/calico/kube-controllers', 'tag': 'v3.27.3', 'sha256': '', 'groups': ['k8s_cluster']}})
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/download_file.yml for master => (item={'key': 'calico_crds', 'value': {'file': True, 'enabled': True, 'version': 'v3.27.3', 'dest': '/tmp/releases/calico-v3.27.3-kdd-crds/v3.27.3.tar.gz', 'sha256': 'd11a32919bff389f642af5df8180ad3cec586030decd35adb2a7d4a8aa3b298e', 'url': 'https://github.com/projectcalico/calico/archive/v3.27.3.tar.gz', 'unarchive': True, 'unarchive_extra_opts': ['--strip=3', '--wildcards', '*/libcalico-go/config/crd/'], 'owner': 'root', 'mode': '0755', 'groups': ['kube_control_plane']}})
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/download_container.yml for master, worker-1, worker-2 => (item={'key': 'pod_infra', 'value': {'enabled': True, 'container': True, 'repo': 'registry.k8s.io/pause', 'tag': '3.9', 'sha256': '', 'groups': ['k8s_cluster']}})
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/download_container.yml for master, worker-1, worker-2 => (item={'key': 'coredns', 'value': {'enabled': True, 'container': True, 'repo': 'registry.k8s.io/coredns/coredns', 'tag': 'v1.11.1', 'sha256': '', 'groups': ['k8s_cluster']}})
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/download_container.yml for master, worker-1, worker-2 => (item={'key': 'nodelocaldns', 'value': {'enabled': True, 'container': True, 'repo': 'registry.k8s.io/dns/k8s-dns-node-cache', 'tag': '1.22.28', 'sha256': '', 'groups': ['k8s_cluster']}})
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/download_container.yml for master => (item={'key': 'dnsautoscaler', 'value': {'enabled': True, 'container': True, 'repo': 'registry.k8s.io/cpa/cluster-proportional-autoscaler', 'tag': 'v1.8.8', 'sha256': '', 'groups': ['kube_control_plane']}})
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/download_container.yml for worker-1, worker-2 => (item={'key': 'nginx', 'value': {'enabled': True, 'container': True, 'repo': 'docker.io/library/nginx', 'tag': '1.25.2-alpine', 'sha256': '', 'groups': ['kube_node']}})
Воскресенье 18 августа 2024  23:46:19 +0300 (0:00:00.994)       0:01:54.846 *** 

TASK [download : Prep_download | Set a few facts] ********************************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:46:19 +0300 (0:00:00.025)       0:01:54.871 *** 

TASK [download : Download_file | Show url of file to dowload] ********************************************************************************************************
ok: [master] => {
    "msg": "https://github.com/etcd-io/etcd/releases/download/v3.5.12/etcd-v3.5.12-linux-amd64.tar.gz"
}
Воскресенье 18 августа 2024  23:46:19 +0300 (0:00:00.026)       0:01:54.898 *** 

TASK [download : Download_file | Set pathname of cached file] ********************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:46:19 +0300 (0:00:00.028)       0:01:54.927 *** 

TASK [download : Download_file | Create dest directory on node] ******************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:46:19 +0300 (0:00:00.299)       0:01:55.226 *** 
Воскресенье 18 августа 2024  23:46:19 +0300 (0:00:00.023)       0:01:55.250 *** 
Воскресенье 18 августа 2024  23:46:19 +0300 (0:00:00.028)       0:01:55.278 *** 

TASK [download : Download_file | Download item] **********************************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:46:20 +0300 (0:00:00.500)       0:01:55.779 *** 
Воскресенье 18 августа 2024  23:46:20 +0300 (0:00:00.024)       0:01:55.804 *** 
Воскресенье 18 августа 2024  23:46:20 +0300 (0:00:00.023)       0:01:55.827 *** 
Воскресенье 18 августа 2024  23:46:20 +0300 (0:00:00.022)       0:01:55.849 *** 

TASK [download : Download_file | Extract file archives] **************************************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/extract_file.yml for master
Воскресенье 18 августа 2024  23:46:20 +0300 (0:00:00.035)       0:01:55.885 *** 

TASK [download : Extract_file | Unpacking archive] *******************************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:46:22 +0300 (0:00:01.914)       0:01:57.799 *** 

TASK [download : Prep_download | Set a few facts] ********************************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:22 +0300 (0:00:00.060)       0:01:57.860 *** 

TASK [download : Download_file | Show url of file to dowload] ********************************************************************************************************
ok: [master] => {
    "msg": "https://github.com/containernetworking/plugins/releases/download/v1.4.0/cni-plugins-linux-amd64-v1.4.0.tgz"
}
ok: [worker-1] => {
    "msg": "https://github.com/containernetworking/plugins/releases/download/v1.4.0/cni-plugins-linux-amd64-v1.4.0.tgz"
}
ok: [worker-2] => {
    "msg": "https://github.com/containernetworking/plugins/releases/download/v1.4.0/cni-plugins-linux-amd64-v1.4.0.tgz"
}
Воскресенье 18 августа 2024  23:46:22 +0300 (0:00:00.057)       0:01:57.917 *** 

TASK [download : Download_file | Set pathname of cached file] ********************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:22 +0300 (0:00:00.058)       0:01:57.976 *** 

TASK [download : Download_file | Create dest directory on node] ******************************************************************************************************
ok: [master]
changed: [worker-1]
changed: [worker-2]
Воскресенье 18 августа 2024  23:46:22 +0300 (0:00:00.344)       0:01:58.320 *** 
Воскресенье 18 августа 2024  23:46:22 +0300 (0:00:00.023)       0:01:58.344 *** 
Воскресенье 18 августа 2024  23:46:22 +0300 (0:00:00.028)       0:01:58.373 *** 

TASK [download : Download_file | Download item] **********************************************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:23 +0300 (0:00:00.621)       0:01:58.994 *** 
Воскресенье 18 августа 2024  23:46:23 +0300 (0:00:00.049)       0:01:59.044 *** 
Воскресенье 18 августа 2024  23:46:23 +0300 (0:00:00.045)       0:01:59.090 *** 
Воскресенье 18 августа 2024  23:46:23 +0300 (0:00:00.045)       0:01:59.135 *** 

TASK [download : Download_file | Extract file archives] **************************************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/extract_file.yml for master, worker-1, worker-2
Воскресенье 18 августа 2024  23:46:23 +0300 (0:00:00.073)       0:01:59.209 *** 
Воскресенье 18 августа 2024  23:46:23 +0300 (0:00:00.051)       0:01:59.260 *** 

TASK [download : Prep_download | Set a few facts] ********************************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:23 +0300 (0:00:00.054)       0:01:59.315 *** 

TASK [download : Download_file | Show url of file to dowload] ********************************************************************************************************
ok: [master] => {
    "msg": "https://dl.k8s.io/release/v1.30.3/bin/linux/amd64/kubeadm"
}
ok: [worker-1] => {
    "msg": "https://dl.k8s.io/release/v1.30.3/bin/linux/amd64/kubeadm"
}
ok: [worker-2] => {
    "msg": "https://dl.k8s.io/release/v1.30.3/bin/linux/amd64/kubeadm"
}
Воскресенье 18 августа 2024  23:46:23 +0300 (0:00:00.060)       0:01:59.375 *** 

TASK [download : Download_file | Set pathname of cached file] ********************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:24 +0300 (0:00:00.057)       0:01:59.433 *** 

TASK [download : Download_file | Create dest directory on node] ******************************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:24 +0300 (0:00:00.344)       0:01:59.777 *** 
Воскресенье 18 августа 2024  23:46:24 +0300 (0:00:00.022)       0:01:59.800 *** 
Воскресенье 18 августа 2024  23:46:24 +0300 (0:00:00.028)       0:01:59.829 *** 

TASK [download : Download_file | Download item] **********************************************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:25 +0300 (0:00:00.633)       0:02:00.463 *** 
Воскресенье 18 августа 2024  23:46:25 +0300 (0:00:00.046)       0:02:00.509 *** 
Воскресенье 18 августа 2024  23:46:25 +0300 (0:00:00.046)       0:02:00.555 *** 
Воскресенье 18 августа 2024  23:46:25 +0300 (0:00:00.052)       0:02:00.608 *** 

TASK [download : Download_file | Extract file archives] **************************************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/extract_file.yml for master, worker-1, worker-2
Воскресенье 18 августа 2024  23:46:25 +0300 (0:00:00.076)       0:02:00.684 *** 
Воскресенье 18 августа 2024  23:46:25 +0300 (0:00:00.058)       0:02:00.743 *** 

TASK [download : Prep_download | Set a few facts] ********************************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:25 +0300 (0:00:00.061)       0:02:00.804 *** 

TASK [download : Download_file | Show url of file to dowload] ********************************************************************************************************
ok: [master] => {
    "msg": "https://dl.k8s.io/release/v1.30.3/bin/linux/amd64/kubelet"
}
ok: [worker-1] => {
    "msg": "https://dl.k8s.io/release/v1.30.3/bin/linux/amd64/kubelet"
}
ok: [worker-2] => {
    "msg": "https://dl.k8s.io/release/v1.30.3/bin/linux/amd64/kubelet"
}
Воскресенье 18 августа 2024  23:46:25 +0300 (0:00:00.065)       0:02:00.870 *** 

TASK [download : Download_file | Set pathname of cached file] ********************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:25 +0300 (0:00:00.057)       0:02:00.927 *** 

TASK [download : Download_file | Create dest directory on node] ******************************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:25 +0300 (0:00:00.349)       0:02:01.277 *** 
Воскресенье 18 августа 2024  23:46:25 +0300 (0:00:00.024)       0:02:01.301 *** 
Воскресенье 18 августа 2024  23:46:25 +0300 (0:00:00.030)       0:02:01.331 *** 

TASK [download : Download_file | Download item] **********************************************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:26 +0300 (0:00:00.799)       0:02:02.131 *** 
Воскресенье 18 августа 2024  23:46:26 +0300 (0:00:00.048)       0:02:02.180 *** 
Воскресенье 18 августа 2024  23:46:26 +0300 (0:00:00.049)       0:02:02.229 *** 
Воскресенье 18 августа 2024  23:46:26 +0300 (0:00:00.047)       0:02:02.277 *** 

TASK [download : Download_file | Extract file archives] **************************************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/extract_file.yml for master, worker-1, worker-2
Воскресенье 18 августа 2024  23:46:26 +0300 (0:00:00.078)       0:02:02.356 *** 
Воскресенье 18 августа 2024  23:46:27 +0300 (0:00:00.059)       0:02:02.415 *** 

TASK [download : Prep_download | Set a few facts] ********************************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:46:27 +0300 (0:00:00.025)       0:02:02.441 *** 

TASK [download : Download_file | Show url of file to dowload] ********************************************************************************************************
ok: [master] => {
    "msg": "https://dl.k8s.io/release/v1.30.3/bin/linux/amd64/kubectl"
}
Воскресенье 18 августа 2024  23:46:27 +0300 (0:00:00.026)       0:02:02.467 *** 

TASK [download : Download_file | Set pathname of cached file] ********************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:46:27 +0300 (0:00:00.026)       0:02:02.494 *** 

TASK [download : Download_file | Create dest directory on node] ******************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:46:27 +0300 (0:00:00.333)       0:02:02.827 *** 
Воскресенье 18 августа 2024  23:46:27 +0300 (0:00:00.024)       0:02:02.852 *** 
Воскресенье 18 августа 2024  23:46:27 +0300 (0:00:00.029)       0:02:02.881 *** 

TASK [download : Download_file | Download item] **********************************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:46:28 +0300 (0:00:00.591)       0:02:03.473 *** 
Воскресенье 18 августа 2024  23:46:28 +0300 (0:00:00.022)       0:02:03.496 *** 
Воскресенье 18 августа 2024  23:46:28 +0300 (0:00:00.025)       0:02:03.522 *** 
Воскресенье 18 августа 2024  23:46:28 +0300 (0:00:00.023)       0:02:03.545 *** 

TASK [download : Download_file | Extract file archives] **************************************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/extract_file.yml for master
Воскресенье 18 августа 2024  23:46:28 +0300 (0:00:00.033)       0:02:03.579 *** 
Воскресенье 18 августа 2024  23:46:28 +0300 (0:00:00.026)       0:02:03.605 *** 

TASK [download : Prep_download | Set a few facts] ********************************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:28 +0300 (0:00:00.075)       0:02:03.681 *** 

TASK [download : Download_file | Show url of file to dowload] ********************************************************************************************************
ok: [master] => {
    "msg": "https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.30.0/crictl-v1.30.0-linux-amd64.tar.gz"
}
ok: [worker-1] => {
    "msg": "https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.30.0/crictl-v1.30.0-linux-amd64.tar.gz"
}
ok: [worker-2] => {
    "msg": "https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.30.0/crictl-v1.30.0-linux-amd64.tar.gz"
}
Воскресенье 18 августа 2024  23:46:28 +0300 (0:00:00.057)       0:02:03.738 *** 

TASK [download : Download_file | Set pathname of cached file] ********************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:28 +0300 (0:00:00.059)       0:02:03.797 *** 

TASK [download : Download_file | Create dest directory on node] ******************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:28 +0300 (0:00:00.353)       0:02:04.150 *** 
Воскресенье 18 августа 2024  23:46:28 +0300 (0:00:00.024)       0:02:04.174 *** 
Воскресенье 18 августа 2024  23:46:28 +0300 (0:00:00.029)       0:02:04.203 *** 

TASK [download : Download_file | Download item] **********************************************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:29 +0300 (0:00:00.538)       0:02:04.742 *** 
Воскресенье 18 августа 2024  23:46:29 +0300 (0:00:00.045)       0:02:04.788 *** 
Воскресенье 18 августа 2024  23:46:29 +0300 (0:00:00.055)       0:02:04.843 *** 
Воскресенье 18 августа 2024  23:46:29 +0300 (0:00:00.046)       0:02:04.890 *** 

TASK [download : Download_file | Extract file archives] **************************************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/extract_file.yml for master, worker-1, worker-2
Воскресенье 18 августа 2024  23:46:29 +0300 (0:00:00.076)       0:02:04.966 *** 

TASK [download : Extract_file | Unpacking archive] *******************************************************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:46:31 +0300 (0:00:02.036)       0:02:07.003 *** 

TASK [download : Prep_download | Set a few facts] ********************************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:31 +0300 (0:00:00.058)       0:02:07.061 *** 

TASK [download : Download_file | Show url of file to dowload] ********************************************************************************************************
ok: [master] => {
    "msg": "https://github.com/opencontainers/runc/releases/download/v1.1.13/runc.amd64"
}
ok: [worker-1] => {
    "msg": "https://github.com/opencontainers/runc/releases/download/v1.1.13/runc.amd64"
}
ok: [worker-2] => {
    "msg": "https://github.com/opencontainers/runc/releases/download/v1.1.13/runc.amd64"
}
Воскресенье 18 августа 2024  23:46:31 +0300 (0:00:00.058)       0:02:07.120 *** 

TASK [download : Download_file | Set pathname of cached file] ********************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:31 +0300 (0:00:00.137)       0:02:07.258 *** 

TASK [download : Download_file | Create dest directory on node] ******************************************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:46:32 +0300 (0:00:00.344)       0:02:07.603 *** 
Воскресенье 18 августа 2024  23:46:32 +0300 (0:00:00.024)       0:02:07.627 *** 
Воскресенье 18 августа 2024  23:46:32 +0300 (0:00:00.028)       0:02:07.655 *** 

TASK [download : Download_file | Download item] **********************************************************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:46:32 +0300 (0:00:00.521)       0:02:08.177 *** 
Воскресенье 18 августа 2024  23:46:32 +0300 (0:00:00.048)       0:02:08.225 *** 
Воскресенье 18 августа 2024  23:46:32 +0300 (0:00:00.044)       0:02:08.270 *** 
Воскресенье 18 августа 2024  23:46:32 +0300 (0:00:00.045)       0:02:08.315 *** 

TASK [download : Download_file | Extract file archives] **************************************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/extract_file.yml for master, worker-1, worker-2
Воскресенье 18 августа 2024  23:46:32 +0300 (0:00:00.077)       0:02:08.393 *** 
Воскресенье 18 августа 2024  23:46:33 +0300 (0:00:00.051)       0:02:08.444 *** 

TASK [download : Prep_download | Set a few facts] ********************************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:33 +0300 (0:00:00.057)       0:02:08.501 *** 

TASK [download : Download_file | Show url of file to dowload] ********************************************************************************************************
ok: [master] => {
    "msg": "https://github.com/containerd/containerd/releases/download/v1.7.20/containerd-1.7.20-linux-amd64.tar.gz"
}
ok: [worker-1] => {
    "msg": "https://github.com/containerd/containerd/releases/download/v1.7.20/containerd-1.7.20-linux-amd64.tar.gz"
}
ok: [worker-2] => {
    "msg": "https://github.com/containerd/containerd/releases/download/v1.7.20/containerd-1.7.20-linux-amd64.tar.gz"
}
Воскресенье 18 августа 2024  23:46:33 +0300 (0:00:00.057)       0:02:08.559 *** 

TASK [download : Download_file | Set pathname of cached file] ********************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:33 +0300 (0:00:00.056)       0:02:08.615 *** 

TASK [download : Download_file | Create dest directory on node] ******************************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:33 +0300 (0:00:00.340)       0:02:08.955 *** 
Воскресенье 18 августа 2024  23:46:33 +0300 (0:00:00.023)       0:02:08.979 *** 
Воскресенье 18 августа 2024  23:46:33 +0300 (0:00:00.036)       0:02:09.015 *** 

TASK [download : Download_file | Download item] **********************************************************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:46:34 +0300 (0:00:00.620)       0:02:09.635 *** 
Воскресенье 18 августа 2024  23:46:34 +0300 (0:00:00.047)       0:02:09.683 *** 
Воскресенье 18 августа 2024  23:46:34 +0300 (0:00:00.050)       0:02:09.734 *** 
Воскресенье 18 августа 2024  23:46:34 +0300 (0:00:00.054)       0:02:09.788 *** 

TASK [download : Download_file | Extract file archives] **************************************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/extract_file.yml for master, worker-1, worker-2
Воскресенье 18 августа 2024  23:46:34 +0300 (0:00:00.072)       0:02:09.860 *** 
Воскресенье 18 августа 2024  23:46:34 +0300 (0:00:00.058)       0:02:09.919 *** 

TASK [download : Prep_download | Set a few facts] ********************************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:34 +0300 (0:00:00.059)       0:02:09.979 *** 

TASK [download : Download_file | Show url of file to dowload] ********************************************************************************************************
ok: [master] => {
    "msg": "https://github.com/containerd/nerdctl/releases/download/v1.7.4/nerdctl-1.7.4-linux-amd64.tar.gz"
}
ok: [worker-1] => {
    "msg": "https://github.com/containerd/nerdctl/releases/download/v1.7.4/nerdctl-1.7.4-linux-amd64.tar.gz"
}
ok: [worker-2] => {
    "msg": "https://github.com/containerd/nerdctl/releases/download/v1.7.4/nerdctl-1.7.4-linux-amd64.tar.gz"
}
Воскресенье 18 августа 2024  23:46:34 +0300 (0:00:00.057)       0:02:10.036 *** 

TASK [download : Download_file | Set pathname of cached file] ********************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:34 +0300 (0:00:00.059)       0:02:10.096 *** 

TASK [download : Download_file | Create dest directory on node] ******************************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:35 +0300 (0:00:00.346)       0:02:10.442 *** 
Воскресенье 18 августа 2024  23:46:35 +0300 (0:00:00.023)       0:02:10.466 *** 
Воскресенье 18 августа 2024  23:46:35 +0300 (0:00:00.028)       0:02:10.495 *** 

TASK [download : Download_file | Download item] **********************************************************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:46:35 +0300 (0:00:00.487)       0:02:10.983 *** 
Воскресенье 18 августа 2024  23:46:35 +0300 (0:00:00.044)       0:02:11.028 *** 
Воскресенье 18 августа 2024  23:46:35 +0300 (0:00:00.049)       0:02:11.077 *** 
Воскресенье 18 августа 2024  23:46:35 +0300 (0:00:00.046)       0:02:11.124 *** 

TASK [download : Download_file | Extract file archives] **************************************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/extract_file.yml for master, worker-1, worker-2
Воскресенье 18 августа 2024  23:46:35 +0300 (0:00:00.074)       0:02:11.199 *** 

TASK [download : Extract_file | Unpacking archive] *******************************************************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:46:37 +0300 (0:00:01.389)       0:02:12.588 *** 

TASK [download : Prep_download | Set a few facts] ********************************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:37 +0300 (0:00:00.055)       0:02:12.644 *** 

TASK [download : Download_file | Show url of file to dowload] ********************************************************************************************************
ok: [master] => {
    "msg": "https://github.com/projectcalico/calico/releases/download/v3.27.3/calicoctl-linux-amd64"
}
ok: [worker-1] => {
    "msg": "https://github.com/projectcalico/calico/releases/download/v3.27.3/calicoctl-linux-amd64"
}
ok: [worker-2] => {
    "msg": "https://github.com/projectcalico/calico/releases/download/v3.27.3/calicoctl-linux-amd64"
}
Воскресенье 18 августа 2024  23:46:37 +0300 (0:00:00.055)       0:02:12.700 *** 

TASK [download : Download_file | Set pathname of cached file] ********************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:37 +0300 (0:00:00.062)       0:02:12.762 *** 

TASK [download : Download_file | Create dest directory on node] ******************************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:37 +0300 (0:00:00.338)       0:02:13.100 *** 
Воскресенье 18 августа 2024  23:46:37 +0300 (0:00:00.023)       0:02:13.124 *** 
Воскресенье 18 августа 2024  23:46:37 +0300 (0:00:00.028)       0:02:13.152 *** 

TASK [download : Download_file | Download item] **********************************************************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:46:38 +0300 (0:00:00.688)       0:02:13.840 *** 
Воскресенье 18 августа 2024  23:46:38 +0300 (0:00:00.046)       0:02:13.887 *** 
Воскресенье 18 августа 2024  23:46:38 +0300 (0:00:00.045)       0:02:13.933 *** 
Воскресенье 18 августа 2024  23:46:38 +0300 (0:00:00.045)       0:02:13.978 *** 

TASK [download : Download_file | Extract file archives] **************************************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/extract_file.yml for master, worker-1, worker-2
Воскресенье 18 августа 2024  23:46:38 +0300 (0:00:00.076)       0:02:14.054 *** 
Воскресенье 18 августа 2024  23:46:38 +0300 (0:00:00.052)       0:02:14.107 *** 

TASK [download : Set default values for flag variables] **************************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:38 +0300 (0:00:00.054)       0:02:14.162 *** 

TASK [download : Set_container_facts | Display the name of the image being processed] ********************************************************************************
ok: [master] => {
    "msg": "quay.io/calico/node"
}
ok: [worker-1] => {
    "msg": "quay.io/calico/node"
}
ok: [worker-2] => {
    "msg": "quay.io/calico/node"
}
Воскресенье 18 августа 2024  23:46:38 +0300 (0:00:00.056)       0:02:14.219 *** 

TASK [download : Set_container_facts | Set if containers should be pulled by digest] *********************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:38 +0300 (0:00:00.058)       0:02:14.277 *** 

TASK [download : Set_container_facts | Define by what name to pull the image] ****************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:38 +0300 (0:00:00.054)       0:02:14.331 *** 

TASK [download : Set_container_facts | Define file name of image] ****************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:38 +0300 (0:00:00.059)       0:02:14.391 *** 

TASK [download : Set_container_facts | Define path of image] *********************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:39 +0300 (0:00:00.055)       0:02:14.446 *** 
Воскресенье 18 августа 2024  23:46:39 +0300 (0:00:00.046)       0:02:14.493 *** 

TASK [download : Set image save/load command for containerd] *********************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:39 +0300 (0:00:00.054)       0:02:14.547 *** 
Воскресенье 18 августа 2024  23:46:39 +0300 (0:00:00.050)       0:02:14.598 *** 
Воскресенье 18 августа 2024  23:46:39 +0300 (0:00:00.047)       0:02:14.646 *** 

TASK [download : Set image save/load command for containerd on localhost] ********************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:39 +0300 (0:00:00.056)       0:02:14.703 *** 
Воскресенье 18 августа 2024  23:46:39 +0300 (0:00:00.050)       0:02:14.754 *** 

TASK [download : Download_container | Prepare container download] ****************************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/check_pull_required.yml for master, worker-1, worker-2
Воскресенье 18 августа 2024  23:46:39 +0300 (0:00:00.083)       0:02:14.837 *** 

TASK [download : Check_pull_required |  Generate a list of information about the images on a node] *******************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:46:40 +0300 (0:00:00.844)       0:02:15.681 *** 

TASK [download : Check_pull_required | Set pull_required if the desired image is not yet loaded] *********************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:40 +0300 (0:00:00.134)       0:02:15.816 *** 
Воскресенье 18 августа 2024  23:46:40 +0300 (0:00:00.047)       0:02:15.863 *** 

TASK [download : debug] **********************************************************************************************************************************************
ok: [master] => {
    "msg": "Pull quay.io/calico/node:v3.27.3 required is: False"
}
ok: [worker-1] => {
    "msg": "Pull quay.io/calico/node:v3.27.3 required is: False"
}
ok: [worker-2] => {
    "msg": "Pull quay.io/calico/node:v3.27.3 required is: False"
}
Воскресенье 18 августа 2024  23:46:40 +0300 (0:00:00.052)       0:02:15.916 *** 
Воскресенье 18 августа 2024  23:46:40 +0300 (0:00:00.052)       0:02:15.969 *** 
Воскресенье 18 августа 2024  23:46:40 +0300 (0:00:00.046)       0:02:16.015 *** 
Воскресенье 18 августа 2024  23:46:40 +0300 (0:00:00.046)       0:02:16.062 *** 
Воскресенье 18 августа 2024  23:46:40 +0300 (0:00:00.057)       0:02:16.119 *** 
Воскресенье 18 августа 2024  23:46:40 +0300 (0:00:00.036)       0:02:16.156 *** 
Воскресенье 18 августа 2024  23:46:40 +0300 (0:00:00.051)       0:02:16.208 *** 
Воскресенье 18 августа 2024  23:46:40 +0300 (0:00:00.046)       0:02:16.254 *** 
Воскресенье 18 августа 2024  23:46:40 +0300 (0:00:00.046)       0:02:16.301 *** 

TASK [download : Download_container | Remove container image from cache] *********************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:41 +0300 (0:00:00.341)       0:02:16.643 *** 

TASK [download : Set default values for flag variables] **************************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:41 +0300 (0:00:00.055)       0:02:16.698 *** 

TASK [download : Set_container_facts | Display the name of the image being processed] ********************************************************************************
ok: [master] => {
    "msg": "quay.io/calico/cni"
}
ok: [worker-1] => {
    "msg": "quay.io/calico/cni"
}
ok: [worker-2] => {
    "msg": "quay.io/calico/cni"
}
Воскресенье 18 августа 2024  23:46:41 +0300 (0:00:00.055)       0:02:16.754 *** 

TASK [download : Set_container_facts | Set if containers should be pulled by digest] *********************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:41 +0300 (0:00:00.057)       0:02:16.812 *** 

TASK [download : Set_container_facts | Define by what name to pull the image] ****************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:41 +0300 (0:00:00.060)       0:02:16.872 *** 

TASK [download : Set_container_facts | Define file name of image] ****************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:41 +0300 (0:00:00.054)       0:02:16.927 *** 

TASK [download : Set_container_facts | Define path of image] *********************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:41 +0300 (0:00:00.054)       0:02:16.981 *** 
Воскресенье 18 августа 2024  23:46:41 +0300 (0:00:00.048)       0:02:17.030 *** 

TASK [download : Set image save/load command for containerd] *********************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:41 +0300 (0:00:00.061)       0:02:17.091 *** 
Воскресенье 18 августа 2024  23:46:41 +0300 (0:00:00.047)       0:02:17.139 *** 
Воскресенье 18 августа 2024  23:46:41 +0300 (0:00:00.046)       0:02:17.185 *** 

TASK [download : Set image save/load command for containerd on localhost] ********************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:41 +0300 (0:00:00.060)       0:02:17.245 *** 
Воскресенье 18 августа 2024  23:46:41 +0300 (0:00:00.053)       0:02:17.299 *** 

TASK [download : Download_container | Prepare container download] ****************************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/check_pull_required.yml for master, worker-1, worker-2
Воскресенье 18 августа 2024  23:46:41 +0300 (0:00:00.085)       0:02:17.384 *** 

TASK [download : Check_pull_required |  Generate a list of information about the images on a node] *******************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:46:42 +0300 (0:00:00.974)       0:02:18.359 *** 

TASK [download : Check_pull_required | Set pull_required if the desired image is not yet loaded] *********************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:43 +0300 (0:00:00.056)       0:02:18.415 *** 
Воскресенье 18 августа 2024  23:46:43 +0300 (0:00:00.047)       0:02:18.463 *** 

TASK [download : debug] **********************************************************************************************************************************************
ok: [master] => {
    "msg": "Pull quay.io/calico/cni:v3.27.3 required is: False"
}
ok: [worker-1] => {
    "msg": "Pull quay.io/calico/cni:v3.27.3 required is: False"
}
ok: [worker-2] => {
    "msg": "Pull quay.io/calico/cni:v3.27.3 required is: False"
}
Воскресенье 18 августа 2024  23:46:43 +0300 (0:00:00.058)       0:02:18.522 *** 
Воскресенье 18 августа 2024  23:46:43 +0300 (0:00:00.050)       0:02:18.572 *** 
Воскресенье 18 августа 2024  23:46:43 +0300 (0:00:00.046)       0:02:18.619 *** 
Воскресенье 18 августа 2024  23:46:43 +0300 (0:00:00.046)       0:02:18.665 *** 
Воскресенье 18 августа 2024  23:46:43 +0300 (0:00:00.065)       0:02:18.730 *** 
Воскресенье 18 августа 2024  23:46:43 +0300 (0:00:00.032)       0:02:18.762 *** 
Воскресенье 18 августа 2024  23:46:43 +0300 (0:00:00.047)       0:02:18.810 *** 
Воскресенье 18 августа 2024  23:46:43 +0300 (0:00:00.045)       0:02:18.856 *** 
Воскресенье 18 августа 2024  23:46:43 +0300 (0:00:00.050)       0:02:18.907 *** 

TASK [download : Download_container | Remove container image from cache] *********************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:43 +0300 (0:00:00.339)       0:02:19.246 *** 

TASK [download : Set default values for flag variables] **************************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:43 +0300 (0:00:00.054)       0:02:19.300 *** 

TASK [download : Set_container_facts | Display the name of the image being processed] ********************************************************************************
ok: [master] => {
    "msg": "quay.io/calico/pod2daemon-flexvol"
}
ok: [worker-1] => {
    "msg": "quay.io/calico/pod2daemon-flexvol"
}
ok: [worker-2] => {
    "msg": "quay.io/calico/pod2daemon-flexvol"
}
Воскресенье 18 августа 2024  23:46:43 +0300 (0:00:00.059)       0:02:19.359 *** 

TASK [download : Set_container_facts | Set if containers should be pulled by digest] *********************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:44 +0300 (0:00:00.061)       0:02:19.421 *** 

TASK [download : Set_container_facts | Define by what name to pull the image] ****************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:44 +0300 (0:00:00.057)       0:02:19.478 *** 

TASK [download : Set_container_facts | Define file name of image] ****************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:44 +0300 (0:00:00.054)       0:02:19.533 *** 

TASK [download : Set_container_facts | Define path of image] *********************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:44 +0300 (0:00:00.060)       0:02:19.593 *** 
Воскресенье 18 августа 2024  23:46:44 +0300 (0:00:00.048)       0:02:19.642 *** 

TASK [download : Set image save/load command for containerd] *********************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:44 +0300 (0:00:00.056)       0:02:19.698 *** 
Воскресенье 18 августа 2024  23:46:44 +0300 (0:00:00.046)       0:02:19.744 *** 
Воскресенье 18 августа 2024  23:46:44 +0300 (0:00:00.053)       0:02:19.797 *** 

TASK [download : Set image save/load command for containerd on localhost] ********************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:44 +0300 (0:00:00.057)       0:02:19.855 *** 
Воскресенье 18 августа 2024  23:46:44 +0300 (0:00:00.048)       0:02:19.903 *** 

TASK [download : Download_container | Prepare container download] ****************************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/check_pull_required.yml for master, worker-1, worker-2
Воскресенье 18 августа 2024  23:46:44 +0300 (0:00:00.084)       0:02:19.988 *** 

TASK [download : Check_pull_required |  Generate a list of information about the images on a node] *******************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:46:45 +0300 (0:00:00.952)       0:02:20.940 *** 

TASK [download : Check_pull_required | Set pull_required if the desired image is not yet loaded] *********************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:45 +0300 (0:00:00.071)       0:02:21.012 *** 
Воскресенье 18 августа 2024  23:46:45 +0300 (0:00:00.058)       0:02:21.071 *** 

TASK [download : debug] **********************************************************************************************************************************************
ok: [master] => {
    "msg": "Pull quay.io/calico/pod2daemon-flexvol:v3.27.3 required is: False"
}
ok: [worker-1] => {
    "msg": "Pull quay.io/calico/pod2daemon-flexvol:v3.27.3 required is: False"
}
ok: [worker-2] => {
    "msg": "Pull quay.io/calico/pod2daemon-flexvol:v3.27.3 required is: False"
}
Воскресенье 18 августа 2024  23:46:45 +0300 (0:00:00.054)       0:02:21.125 *** 
Воскресенье 18 августа 2024  23:46:45 +0300 (0:00:00.048)       0:02:21.174 *** 
Воскресенье 18 августа 2024  23:46:45 +0300 (0:00:00.049)       0:02:21.223 *** 
Воскресенье 18 августа 2024  23:46:45 +0300 (0:00:00.046)       0:02:21.270 *** 
Воскресенье 18 августа 2024  23:46:45 +0300 (0:00:00.058)       0:02:21.329 *** 
Воскресенье 18 августа 2024  23:46:45 +0300 (0:00:00.031)       0:02:21.361 *** 
Воскресенье 18 августа 2024  23:46:45 +0300 (0:00:00.049)       0:02:21.410 *** 
Воскресенье 18 августа 2024  23:46:46 +0300 (0:00:00.126)       0:02:21.537 *** 
Воскресенье 18 августа 2024  23:46:46 +0300 (0:00:00.046)       0:02:21.583 *** 

TASK [download : Download_container | Remove container image from cache] *********************************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:46:46 +0300 (0:00:00.395)       0:02:21.979 *** 

TASK [download : Set default values for flag variables] **************************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:46 +0300 (0:00:00.057)       0:02:22.036 *** 

TASK [download : Set_container_facts | Display the name of the image being processed] ********************************************************************************
ok: [master] => {
    "msg": "quay.io/calico/kube-controllers"
}
ok: [worker-1] => {
    "msg": "quay.io/calico/kube-controllers"
}
ok: [worker-2] => {
    "msg": "quay.io/calico/kube-controllers"
}
Воскресенье 18 августа 2024  23:46:46 +0300 (0:00:00.056)       0:02:22.093 *** 

TASK [download : Set_container_facts | Set if containers should be pulled by digest] *********************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:46 +0300 (0:00:00.063)       0:02:22.156 *** 

TASK [download : Set_container_facts | Define by what name to pull the image] ****************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:46 +0300 (0:00:00.055)       0:02:22.212 *** 

TASK [download : Set_container_facts | Define file name of image] ****************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:46 +0300 (0:00:00.060)       0:02:22.272 *** 

TASK [download : Set_container_facts | Define path of image] *********************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:46 +0300 (0:00:00.055)       0:02:22.327 *** 
Воскресенье 18 августа 2024  23:46:46 +0300 (0:00:00.046)       0:02:22.374 *** 

TASK [download : Set image save/load command for containerd] *********************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:47 +0300 (0:00:00.058)       0:02:22.432 *** 
Воскресенье 18 августа 2024  23:46:47 +0300 (0:00:00.051)       0:02:22.484 *** 
Воскресенье 18 августа 2024  23:46:47 +0300 (0:00:00.047)       0:02:22.532 *** 

TASK [download : Set image save/load command for containerd on localhost] ********************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:47 +0300 (0:00:00.057)       0:02:22.589 *** 
Воскресенье 18 августа 2024  23:46:47 +0300 (0:00:00.050)       0:02:22.639 *** 

TASK [download : Download_container | Prepare container download] ****************************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/check_pull_required.yml for master, worker-1, worker-2
Воскресенье 18 августа 2024  23:46:47 +0300 (0:00:00.084)       0:02:22.723 *** 

TASK [download : Check_pull_required |  Generate a list of information about the images on a node] *******************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:46:48 +0300 (0:00:00.823)       0:02:23.547 *** 

TASK [download : Check_pull_required | Set pull_required if the desired image is not yet loaded] *********************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:48 +0300 (0:00:00.058)       0:02:23.605 *** 
Воскресенье 18 августа 2024  23:46:48 +0300 (0:00:00.048)       0:02:23.653 *** 

TASK [download : debug] **********************************************************************************************************************************************
ok: [master] => {
    "msg": "Pull quay.io/calico/kube-controllers:v3.27.3 required is: False"
}
ok: [worker-1] => {
    "msg": "Pull quay.io/calico/kube-controllers:v3.27.3 required is: False"
}
ok: [worker-2] => {
    "msg": "Pull quay.io/calico/kube-controllers:v3.27.3 required is: False"
}
Воскресенье 18 августа 2024  23:46:48 +0300 (0:00:00.055)       0:02:23.709 *** 
Воскресенье 18 августа 2024  23:46:48 +0300 (0:00:00.056)       0:02:23.766 *** 
Воскресенье 18 августа 2024  23:46:48 +0300 (0:00:00.046)       0:02:23.812 *** 
Воскресенье 18 августа 2024  23:46:48 +0300 (0:00:00.045)       0:02:23.858 *** 
Воскресенье 18 августа 2024  23:46:48 +0300 (0:00:00.061)       0:02:23.919 *** 
Воскресенье 18 августа 2024  23:46:48 +0300 (0:00:00.040)       0:02:23.960 *** 
Воскресенье 18 августа 2024  23:46:48 +0300 (0:00:00.048)       0:02:24.008 *** 
Воскресенье 18 августа 2024  23:46:48 +0300 (0:00:00.046)       0:02:24.055 *** 
Воскресенье 18 августа 2024  23:46:48 +0300 (0:00:00.046)       0:02:24.101 *** 

TASK [download : Download_container | Remove container image from cache] *********************************************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:46:49 +0300 (0:00:00.346)       0:02:24.447 *** 

TASK [download : Prep_download | Set a few facts] ********************************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:46:49 +0300 (0:00:00.026)       0:02:24.474 *** 

TASK [download : Download_file | Show url of file to dowload] ********************************************************************************************************
ok: [master] => {
    "msg": "https://github.com/projectcalico/calico/archive/v3.27.3.tar.gz"
}
Воскресенье 18 августа 2024  23:46:49 +0300 (0:00:00.027)       0:02:24.502 *** 

TASK [download : Download_file | Set pathname of cached file] ********************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:46:49 +0300 (0:00:00.027)       0:02:24.529 *** 

TASK [download : Download_file | Create dest directory on node] ******************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:46:49 +0300 (0:00:00.297)       0:02:24.826 *** 
Воскресенье 18 августа 2024  23:46:49 +0300 (0:00:00.025)       0:02:24.852 *** 
Воскресенье 18 августа 2024  23:46:49 +0300 (0:00:00.030)       0:02:24.882 *** 

TASK [download : Download_file | Download item] **********************************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:46:49 +0300 (0:00:00.458)       0:02:25.341 *** 
Воскресенье 18 августа 2024  23:46:49 +0300 (0:00:00.022)       0:02:25.364 *** 
Воскресенье 18 августа 2024  23:46:49 +0300 (0:00:00.025)       0:02:25.390 *** 
Воскресенье 18 августа 2024  23:46:50 +0300 (0:00:00.023)       0:02:25.414 *** 

TASK [download : Download_file | Extract file archives] **************************************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/extract_file.yml for master
Воскресенье 18 августа 2024  23:46:50 +0300 (0:00:00.034)       0:02:25.448 *** 

TASK [download : Extract_file | Unpacking archive] *******************************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:46:51 +0300 (0:00:01.341)       0:02:26.790 *** 

TASK [download : Set default values for flag variables] **************************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:51 +0300 (0:00:00.058)       0:02:26.848 *** 

TASK [download : Set_container_facts | Display the name of the image being processed] ********************************************************************************
ok: [master] => {
    "msg": "registry.k8s.io/pause"
}
ok: [worker-1] => {
    "msg": "registry.k8s.io/pause"
}
ok: [worker-2] => {
    "msg": "registry.k8s.io/pause"
}
Воскресенье 18 августа 2024  23:46:51 +0300 (0:00:00.057)       0:02:26.906 *** 

TASK [download : Set_container_facts | Set if containers should be pulled by digest] *********************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:51 +0300 (0:00:00.058)       0:02:26.964 *** 

TASK [download : Set_container_facts | Define by what name to pull the image] ****************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:51 +0300 (0:00:00.063)       0:02:27.027 *** 

TASK [download : Set_container_facts | Define file name of image] ****************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:51 +0300 (0:00:00.056)       0:02:27.084 *** 

TASK [download : Set_container_facts | Define path of image] *********************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:51 +0300 (0:00:00.055)       0:02:27.139 *** 
Воскресенье 18 августа 2024  23:46:51 +0300 (0:00:00.046)       0:02:27.185 *** 

TASK [download : Set image save/load command for containerd] *********************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:51 +0300 (0:00:00.062)       0:02:27.248 *** 
Воскресенье 18 августа 2024  23:46:51 +0300 (0:00:00.047)       0:02:27.295 *** 
Воскресенье 18 августа 2024  23:46:51 +0300 (0:00:00.047)       0:02:27.343 *** 

TASK [download : Set image save/load command for containerd on localhost] ********************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:51 +0300 (0:00:00.061)       0:02:27.404 *** 
Воскресенье 18 августа 2024  23:46:52 +0300 (0:00:00.049)       0:02:27.453 *** 

TASK [download : Download_container | Prepare container download] ****************************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/check_pull_required.yml for master, worker-1, worker-2
Воскресенье 18 августа 2024  23:46:52 +0300 (0:00:00.085)       0:02:27.539 *** 

TASK [download : Check_pull_required |  Generate a list of information about the images on a node] *******************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:46:53 +0300 (0:00:00.911)       0:02:28.450 *** 

TASK [download : Check_pull_required | Set pull_required if the desired image is not yet loaded] *********************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:53 +0300 (0:00:00.057)       0:02:28.508 *** 
Воскресенье 18 августа 2024  23:46:53 +0300 (0:00:00.047)       0:02:28.556 *** 

TASK [download : debug] **********************************************************************************************************************************************
ok: [master] => {
    "msg": "Pull registry.k8s.io/pause:3.9 required is: False"
}
ok: [worker-1] => {
    "msg": "Pull registry.k8s.io/pause:3.9 required is: False"
}
ok: [worker-2] => {
    "msg": "Pull registry.k8s.io/pause:3.9 required is: False"
}
Воскресенье 18 августа 2024  23:46:53 +0300 (0:00:00.059)       0:02:28.615 *** 
Воскресенье 18 августа 2024  23:46:53 +0300 (0:00:00.050)       0:02:28.666 *** 
Воскресенье 18 августа 2024  23:46:53 +0300 (0:00:00.047)       0:02:28.713 *** 
Воскресенье 18 августа 2024  23:46:53 +0300 (0:00:00.045)       0:02:28.759 *** 
Воскресенье 18 августа 2024  23:46:53 +0300 (0:00:00.163)       0:02:28.922 *** 
Воскресенье 18 августа 2024  23:46:53 +0300 (0:00:00.032)       0:02:28.954 *** 
Воскресенье 18 августа 2024  23:46:53 +0300 (0:00:00.047)       0:02:29.001 *** 
Воскресенье 18 августа 2024  23:46:53 +0300 (0:00:00.046)       0:02:29.047 *** 
Воскресенье 18 августа 2024  23:46:53 +0300 (0:00:00.048)       0:02:29.096 *** 

TASK [download : Download_container | Remove container image from cache] *********************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:54 +0300 (0:00:00.342)       0:02:29.439 *** 

TASK [download : Set default values for flag variables] **************************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:54 +0300 (0:00:00.054)       0:02:29.494 *** 

TASK [download : Set_container_facts | Display the name of the image being processed] ********************************************************************************
ok: [master] => {
    "msg": "registry.k8s.io/coredns/coredns"
}
ok: [worker-1] => {
    "msg": "registry.k8s.io/coredns/coredns"
}
ok: [worker-2] => {
    "msg": "registry.k8s.io/coredns/coredns"
}
Воскресенье 18 августа 2024  23:46:54 +0300 (0:00:00.055)       0:02:29.549 *** 

TASK [download : Set_container_facts | Set if containers should be pulled by digest] *********************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:54 +0300 (0:00:00.068)       0:02:29.618 *** 

TASK [download : Set_container_facts | Define by what name to pull the image] ****************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:54 +0300 (0:00:00.059)       0:02:29.677 *** 

TASK [download : Set_container_facts | Define file name of image] ****************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:54 +0300 (0:00:00.054)       0:02:29.731 *** 

TASK [download : Set_container_facts | Define path of image] *********************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:54 +0300 (0:00:00.058)       0:02:29.790 *** 
Воскресенье 18 августа 2024  23:46:54 +0300 (0:00:00.048)       0:02:29.838 *** 

TASK [download : Set image save/load command for containerd] *********************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:54 +0300 (0:00:00.054)       0:02:29.893 *** 
Воскресенье 18 августа 2024  23:46:54 +0300 (0:00:00.046)       0:02:29.939 *** 
Воскресенье 18 августа 2024  23:46:54 +0300 (0:00:00.051)       0:02:29.991 *** 

TASK [download : Set image save/load command for containerd on localhost] ********************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:54 +0300 (0:00:00.056)       0:02:30.047 *** 
Воскресенье 18 августа 2024  23:46:54 +0300 (0:00:00.046)       0:02:30.094 *** 

TASK [download : Download_container | Prepare container download] ****************************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/check_pull_required.yml for master, worker-1, worker-2
Воскресенье 18 августа 2024  23:46:54 +0300 (0:00:00.083)       0:02:30.177 *** 

TASK [download : Check_pull_required |  Generate a list of information about the images on a node] *******************************************************************
ok: [worker-1]
ok: [worker-2]
ok: [master]
Воскресенье 18 августа 2024  23:46:55 +0300 (0:00:00.990)       0:02:31.168 *** 

TASK [download : Check_pull_required | Set pull_required if the desired image is not yet loaded] *********************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:55 +0300 (0:00:00.056)       0:02:31.225 *** 
Воскресенье 18 августа 2024  23:46:55 +0300 (0:00:00.051)       0:02:31.276 *** 

TASK [download : debug] **********************************************************************************************************************************************
ok: [master] => {
    "msg": "Pull registry.k8s.io/coredns/coredns:v1.11.1 required is: False"
}
ok: [worker-1] => {
    "msg": "Pull registry.k8s.io/coredns/coredns:v1.11.1 required is: False"
}
ok: [worker-2] => {
    "msg": "Pull registry.k8s.io/coredns/coredns:v1.11.1 required is: False"
}
Воскресенье 18 августа 2024  23:46:55 +0300 (0:00:00.053)       0:02:31.329 *** 
Воскресенье 18 августа 2024  23:46:55 +0300 (0:00:00.051)       0:02:31.380 *** 
Воскресенье 18 августа 2024  23:46:56 +0300 (0:00:00.049)       0:02:31.429 *** 
Воскресенье 18 августа 2024  23:46:56 +0300 (0:00:00.046)       0:02:31.476 *** 
Воскресенье 18 августа 2024  23:46:56 +0300 (0:00:00.057)       0:02:31.533 *** 
Воскресенье 18 августа 2024  23:46:56 +0300 (0:00:00.032)       0:02:31.565 *** 
Воскресенье 18 августа 2024  23:46:56 +0300 (0:00:00.047)       0:02:31.613 *** 
Воскресенье 18 августа 2024  23:46:56 +0300 (0:00:00.049)       0:02:31.663 *** 
Воскресенье 18 августа 2024  23:46:56 +0300 (0:00:00.046)       0:02:31.709 *** 

TASK [download : Download_container | Remove container image from cache] *********************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:56 +0300 (0:00:00.339)       0:02:32.049 *** 

TASK [download : Set default values for flag variables] **************************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:56 +0300 (0:00:00.056)       0:02:32.105 *** 

TASK [download : Set_container_facts | Display the name of the image being processed] ********************************************************************************
ok: [master] => {
    "msg": "registry.k8s.io/dns/k8s-dns-node-cache"
}
ok: [worker-1] => {
    "msg": "registry.k8s.io/dns/k8s-dns-node-cache"
}
ok: [worker-2] => {
    "msg": "registry.k8s.io/dns/k8s-dns-node-cache"
}
Воскресенье 18 августа 2024  23:46:56 +0300 (0:00:00.058)       0:02:32.163 *** 

TASK [download : Set_container_facts | Set if containers should be pulled by digest] *********************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:56 +0300 (0:00:00.060)       0:02:32.224 *** 

TASK [download : Set_container_facts | Define by what name to pull the image] ****************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:56 +0300 (0:00:00.056)       0:02:32.280 *** 

TASK [download : Set_container_facts | Define file name of image] ****************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:56 +0300 (0:00:00.058)       0:02:32.338 *** 

TASK [download : Set_container_facts | Define path of image] *********************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:56 +0300 (0:00:00.053)       0:02:32.392 *** 
Воскресенье 18 августа 2024  23:46:57 +0300 (0:00:00.044)       0:02:32.437 *** 

TASK [download : Set image save/load command for containerd] *********************************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:57 +0300 (0:00:00.053)       0:02:32.490 *** 
Воскресенье 18 августа 2024  23:46:57 +0300 (0:00:00.049)       0:02:32.540 *** 
Воскресенье 18 августа 2024  23:46:57 +0300 (0:00:00.045)       0:02:32.586 *** 

TASK [download : Set image save/load command for containerd on localhost] ********************************************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:57 +0300 (0:00:00.056)       0:02:32.643 *** 
Воскресенье 18 августа 2024  23:46:57 +0300 (0:00:00.052)       0:02:32.696 *** 

TASK [download : Download_container | Prepare container download] ****************************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/check_pull_required.yml for master, worker-1, worker-2
Воскресенье 18 августа 2024  23:46:57 +0300 (0:00:00.082)       0:02:32.779 *** 

TASK [download : Check_pull_required |  Generate a list of information about the images on a node] *******************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:58 +0300 (0:00:00.821)       0:02:33.600 *** 

TASK [download : Check_pull_required | Set pull_required if the desired image is not yet loaded] *********************************************************************
ok: [master]
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:58 +0300 (0:00:00.057)       0:02:33.658 *** 
Воскресенье 18 августа 2024  23:46:58 +0300 (0:00:00.048)       0:02:33.706 *** 

TASK [download : debug] **********************************************************************************************************************************************
ok: [master] => {
    "msg": "Pull registry.k8s.io/dns/k8s-dns-node-cache:1.22.28 required is: False"
}
ok: [worker-1] => {
    "msg": "Pull registry.k8s.io/dns/k8s-dns-node-cache:1.22.28 required is: False"
}
ok: [worker-2] => {
    "msg": "Pull registry.k8s.io/dns/k8s-dns-node-cache:1.22.28 required is: False"
}
Воскресенье 18 августа 2024  23:46:58 +0300 (0:00:00.055)       0:02:33.761 *** 
Воскресенье 18 августа 2024  23:46:58 +0300 (0:00:00.056)       0:02:33.818 *** 
Воскресенье 18 августа 2024  23:46:58 +0300 (0:00:00.045)       0:02:33.863 *** 
Воскресенье 18 августа 2024  23:46:58 +0300 (0:00:00.047)       0:02:33.910 *** 
Воскресенье 18 августа 2024  23:46:58 +0300 (0:00:00.057)       0:02:33.967 *** 
Воскресенье 18 августа 2024  23:46:58 +0300 (0:00:00.040)       0:02:34.008 *** 
Воскресенье 18 августа 2024  23:46:58 +0300 (0:00:00.047)       0:02:34.055 *** 
Воскресенье 18 августа 2024  23:46:58 +0300 (0:00:00.044)       0:02:34.100 *** 
Воскресенье 18 августа 2024  23:46:58 +0300 (0:00:00.044)       0:02:34.145 *** 

TASK [download : Download_container | Remove container image from cache] *********************************************************************************************
ok: [worker-1]
ok: [master]
ok: [worker-2]
Воскресенье 18 августа 2024  23:46:59 +0300 (0:00:00.343)       0:02:34.489 *** 

TASK [download : Set default values for flag variables] **************************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:46:59 +0300 (0:00:00.024)       0:02:34.513 *** 

TASK [download : Set_container_facts | Display the name of the image being processed] ********************************************************************************
ok: [master] => {
    "msg": "registry.k8s.io/cpa/cluster-proportional-autoscaler"
}
Воскресенье 18 августа 2024  23:46:59 +0300 (0:00:00.025)       0:02:34.539 *** 

TASK [download : Set_container_facts | Set if containers should be pulled by digest] *********************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:46:59 +0300 (0:00:00.028)       0:02:34.568 *** 

TASK [download : Set_container_facts | Define by what name to pull the image] ****************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:46:59 +0300 (0:00:00.100)       0:02:34.668 *** 

TASK [download : Set_container_facts | Define file name of image] ****************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:46:59 +0300 (0:00:00.025)       0:02:34.694 *** 

TASK [download : Set_container_facts | Define path of image] *********************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:46:59 +0300 (0:00:00.024)       0:02:34.719 *** 
Воскресенье 18 августа 2024  23:46:59 +0300 (0:00:00.022)       0:02:34.742 *** 

TASK [download : Set image save/load command for containerd] *********************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:46:59 +0300 (0:00:00.028)       0:02:34.770 *** 
Воскресенье 18 августа 2024  23:46:59 +0300 (0:00:00.023)       0:02:34.793 *** 
Воскресенье 18 августа 2024  23:46:59 +0300 (0:00:00.023)       0:02:34.816 *** 

TASK [download : Set image save/load command for containerd on localhost] ********************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:46:59 +0300 (0:00:00.027)       0:02:34.843 *** 
Воскресенье 18 августа 2024  23:46:59 +0300 (0:00:00.025)       0:02:34.869 *** 

TASK [download : Download_container | Prepare container download] ****************************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/check_pull_required.yml for master
Воскресенье 18 августа 2024  23:46:59 +0300 (0:00:00.037)       0:02:34.906 *** 

TASK [download : Check_pull_required |  Generate a list of information about the images on a node] *******************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:47:00 +0300 (0:00:00.885)       0:02:35.792 *** 

TASK [download : Check_pull_required | Set pull_required if the desired image is not yet loaded] *********************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:47:00 +0300 (0:00:00.025)       0:02:35.817 *** 
Воскресенье 18 августа 2024  23:47:00 +0300 (0:00:00.025)       0:02:35.843 *** 

TASK [download : debug] **********************************************************************************************************************************************
ok: [master] => {
    "msg": "Pull registry.k8s.io/cpa/cluster-proportional-autoscaler:v1.8.8 required is: False"
}
Воскресенье 18 августа 2024  23:47:00 +0300 (0:00:00.024)       0:02:35.867 *** 
Воскресенье 18 августа 2024  23:47:00 +0300 (0:00:00.022)       0:02:35.890 *** 
Воскресенье 18 августа 2024  23:47:00 +0300 (0:00:00.022)       0:02:35.912 *** 
Воскресенье 18 августа 2024  23:47:00 +0300 (0:00:00.025)       0:02:35.937 *** 
Воскресенье 18 августа 2024  23:47:00 +0300 (0:00:00.027)       0:02:35.964 *** 
Воскресенье 18 августа 2024  23:47:00 +0300 (0:00:00.032)       0:02:35.997 *** 
Воскресенье 18 августа 2024  23:47:00 +0300 (0:00:00.022)       0:02:36.019 *** 
Воскресенье 18 августа 2024  23:47:00 +0300 (0:00:00.025)       0:02:36.045 *** 
Воскресенье 18 августа 2024  23:47:00 +0300 (0:00:00.023)       0:02:36.068 *** 

TASK [download : Download_container | Remove container image from cache] *********************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:47:00 +0300 (0:00:00.300)       0:02:36.369 *** 

TASK [download : Set default values for flag variables] **************************************************************************************************************
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:47:01 +0300 (0:00:00.044)       0:02:36.414 *** 

TASK [download : Set_container_facts | Display the name of the image being processed] ********************************************************************************
ok: [worker-1] => {
    "msg": "docker.io/library/nginx"
}
ok: [worker-2] => {
    "msg": "docker.io/library/nginx"
}
Воскресенье 18 августа 2024  23:47:01 +0300 (0:00:00.049)       0:02:36.463 *** 

TASK [download : Set_container_facts | Set if containers should be pulled by digest] *********************************************************************************
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:47:01 +0300 (0:00:00.059)       0:02:36.523 *** 

TASK [download : Set_container_facts | Define by what name to pull the image] ****************************************************************************************
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:47:01 +0300 (0:00:00.047)       0:02:36.570 *** 

TASK [download : Set_container_facts | Define file name of image] ****************************************************************************************************
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:47:01 +0300 (0:00:00.045)       0:02:36.616 *** 

TASK [download : Set_container_facts | Define path of image] *********************************************************************************************************
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:47:01 +0300 (0:00:00.054)       0:02:36.671 *** 
Воскресенье 18 августа 2024  23:47:01 +0300 (0:00:00.038)       0:02:36.709 *** 

TASK [download : Set image save/load command for containerd] *********************************************************************************************************
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:47:01 +0300 (0:00:00.049)       0:02:36.759 *** 
Воскресенье 18 августа 2024  23:47:01 +0300 (0:00:00.038)       0:02:36.798 *** 
Воскресенье 18 августа 2024  23:47:01 +0300 (0:00:00.041)       0:02:36.839 *** 

TASK [download : Set image save/load command for containerd on localhost] ********************************************************************************************
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:47:01 +0300 (0:00:00.049)       0:02:36.889 *** 
Воскресенье 18 августа 2024  23:47:01 +0300 (0:00:00.041)       0:02:36.931 *** 

TASK [download : Download_container | Prepare container download] ****************************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/check_pull_required.yml for worker-1, worker-2
Воскресенье 18 августа 2024  23:47:01 +0300 (0:00:00.065)       0:02:36.997 *** 

TASK [download : Check_pull_required |  Generate a list of information about the images on a node] *******************************************************************
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:47:02 +0300 (0:00:00.810)       0:02:37.808 *** 

TASK [download : Check_pull_required | Set pull_required if the desired image is not yet loaded] *********************************************************************
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:47:02 +0300 (0:00:00.053)       0:02:37.862 *** 
Воскресенье 18 августа 2024  23:47:02 +0300 (0:00:00.046)       0:02:37.908 *** 

TASK [download : debug] **********************************************************************************************************************************************
ok: [worker-1] => {
    "msg": "Pull docker.io/library/nginx:1.25.2-alpine required is: False"
}
ok: [worker-2] => {
    "msg": "Pull docker.io/library/nginx:1.25.2-alpine required is: False"
}
Воскресенье 18 августа 2024  23:47:02 +0300 (0:00:00.046)       0:02:37.955 *** 
Воскресенье 18 августа 2024  23:47:02 +0300 (0:00:00.040)       0:02:37.996 *** 
Воскресенье 18 августа 2024  23:47:02 +0300 (0:00:00.036)       0:02:38.033 *** 
Воскресенье 18 августа 2024  23:47:02 +0300 (0:00:00.039)       0:02:38.072 *** 
Воскресенье 18 августа 2024  23:47:02 +0300 (0:00:00.050)       0:02:38.123 *** 
Воскресенье 18 августа 2024  23:47:02 +0300 (0:00:00.037)       0:02:38.161 *** 
Воскресенье 18 августа 2024  23:47:02 +0300 (0:00:00.037)       0:02:38.199 *** 
Воскресенье 18 августа 2024  23:47:02 +0300 (0:00:00.036)       0:02:38.235 *** 
Воскресенье 18 августа 2024  23:47:02 +0300 (0:00:00.042)       0:02:38.278 *** 

TASK [download : Download_container | Remove container image from cache] *********************************************************************************************
ok: [worker-1]
ok: [worker-2]

PLAY [Add worker nodes to the etcd play if needed] *******************************************************************************************************************
Воскресенье 18 августа 2024  23:47:03 +0300 (0:00:00.384)       0:02:38.663 *** 

TASK [Gathering Facts] ***********************************************************************************************************************************************
ok: [worker-1]
ok: [worker-2]
Воскресенье 18 августа 2024  23:47:04 +0300 (0:00:01.121)       0:02:39.784 *** 
Воскресенье 18 августа 2024  23:47:04 +0300 (0:00:00.058)       0:02:39.842 *** 
Воскресенье 18 августа 2024  23:47:04 +0300 (0:00:00.028)       0:02:39.871 *** 
Воскресенье 18 августа 2024  23:47:04 +0300 (0:00:00.040)       0:02:39.912 *** 
Воскресенье 18 августа 2024  23:47:04 +0300 (0:00:00.028)       0:02:39.941 *** 
Воскресенье 18 августа 2024  23:47:04 +0300 (0:00:00.121)       0:02:40.062 *** 
Воскресенье 18 августа 2024  23:47:04 +0300 (0:00:00.053)       0:02:40.116 *** 
[WARNING]: Could not match supplied host pattern, ignoring: _kubespray_needs_etcd

PLAY [Install etcd] **************************************************************************************************************************************************
Воскресенье 18 августа 2024  23:47:04 +0300 (0:00:00.094)       0:02:40.210 *** 
Воскресенье 18 августа 2024  23:47:04 +0300 (0:00:00.061)       0:02:40.272 *** 
Воскресенье 18 августа 2024  23:47:04 +0300 (0:00:00.026)       0:02:40.299 *** 
Воскресенье 18 августа 2024  23:47:04 +0300 (0:00:00.031)       0:02:40.330 *** 
Воскресенье 18 августа 2024  23:47:04 +0300 (0:00:00.027)       0:02:40.357 *** 
Воскресенье 18 августа 2024  23:47:04 +0300 (0:00:00.025)       0:02:40.382 *** 
Воскресенье 18 августа 2024  23:47:04 +0300 (0:00:00.026)       0:02:40.409 *** 

TASK [adduser : User | Create User Group] ****************************************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:47:05 +0300 (0:00:00.306)       0:02:40.715 *** 

TASK [adduser : User | Create User] **********************************************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:47:05 +0300 (0:00:00.351)       0:02:41.067 *** 

TASK [adduser : User | Create User Group] ****************************************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:47:05 +0300 (0:00:00.271)       0:02:41.338 *** 

TASK [adduser : User | Create User] **********************************************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:47:06 +0300 (0:00:00.350)       0:02:41.689 *** 

TASK [etcd : Check etcd certs] ***************************************************************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/etcd/tasks/check_certs.yml for master
Воскресенье 18 августа 2024  23:47:06 +0300 (0:00:00.033)       0:02:41.723 *** 

TASK [etcd : Check_certs | Register certs that have already been generated on first etcd node] ***********************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:47:06 +0300 (0:00:00.297)       0:02:42.020 *** 

TASK [etcd : Check_certs | Set default value for 'sync_certs', 'gen_certs' and 'etcd_secret_changed' to false] *******************************************************
ok: [master]
Воскресенье 18 августа 2024  23:47:06 +0300 (0:00:00.025)       0:02:42.046 *** 

TASK [etcd : Check certs | Register ca and etcd admin/member certs on etcd hosts] ************************************************************************************
ok: [master] => (item=ca.pem)
ok: [master] => (item=member-master.pem)
ok: [master] => (item=member-master-key.pem)
ok: [master] => (item=admin-master.pem)
ok: [master] => (item=admin-master-key.pem)
Воскресенье 18 августа 2024  23:47:07 +0300 (0:00:01.283)       0:02:43.330 *** 

TASK [etcd : Check certs | Register ca and etcd node certs on kubernetes hosts] **************************************************************************************
ok: [master] => (item=ca.pem)
ok: [master] => (item=node-master.pem)
ok: [master] => (item=node-master-key.pem)
Воскресенье 18 августа 2024  23:47:08 +0300 (0:00:00.876)       0:02:44.206 *** 

TASK [etcd : Check_certs | Set 'gen_certs' to true if expected certificates are not on the first etcd node(1/2)] *****************************************************
ok: [master] => (item=/etc/ssl/etcd/ssl/ca.pem)
ok: [master] => (item=/etc/ssl/etcd/ssl/admin-master.pem)
ok: [master] => (item=/etc/ssl/etcd/ssl/admin-master-key.pem)
ok: [master] => (item=/etc/ssl/etcd/ssl/member-master.pem)
ok: [master] => (item=/etc/ssl/etcd/ssl/member-master-key.pem)
ok: [master] => (item=/etc/ssl/etcd/ssl/node-master.pem)
ok: [master] => (item=/etc/ssl/etcd/ssl/node-master-key.pem)
Воскресенье 18 августа 2024  23:47:08 +0300 (0:00:00.077)       0:02:44.284 *** 
Воскресенье 18 августа 2024  23:47:08 +0300 (0:00:00.068)       0:02:44.352 *** 

TASK [etcd : Check_certs | Set 'gen_*_certs' groups to track which nodes needs to have certs generated on first etcd node] *******************************************
changed: [master] => (item={'node_type': 'master', 'certs': ['/etc/ssl/etcd/ssl/member-master.pem', '/etc/ssl/etcd/ssl/member-master-key.pem', '/etc/ssl/etcd/ssl/admin-master.pem', '/etc/ssl/etcd/ssl/admin-master-key.pem']})
changed: [master] => (item={'node_type': 'node', 'certs': ['/etc/ssl/etcd/ssl/node-master.pem', '/etc/ssl/etcd/ssl/node-master-key.pem']})
Воскресенье 18 августа 2024  23:47:08 +0300 (0:00:00.044)       0:02:44.397 *** 
Воскресенье 18 августа 2024  23:47:09 +0300 (0:00:00.042)       0:02:44.439 *** 
Воскресенье 18 августа 2024  23:47:09 +0300 (0:00:00.021)       0:02:44.460 *** 

TASK [etcd : Check_certs | Set 'sync_certs' to true] *****************************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:47:09 +0300 (0:00:00.026)       0:02:44.487 *** 

TASK [etcd : Generate etcd certs] ************************************************************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/etcd/tasks/gen_certs_script.yml for master
Воскресенье 18 августа 2024  23:47:09 +0300 (0:00:00.038)       0:02:44.526 *** 

TASK [etcd : Gen_certs | create etcd cert dir] ***********************************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:47:09 +0300 (0:00:00.289)       0:02:44.815 *** 

TASK [etcd : Gen_certs | create etcd script dir (on master)] *********************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:47:09 +0300 (0:00:00.316)       0:02:45.131 *** 

TASK [etcd : Gen_certs | write openssl config] ***********************************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:47:10 +0300 (0:00:00.760)       0:02:45.892 *** 

TASK [etcd : Gen_certs | copy certs generation script] ***************************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:47:11 +0300 (0:00:00.656)       0:02:46.549 *** 

TASK [etcd : Gen_certs | run cert generation script for etcd and kube control plane nodes] ***************************************************************************
changed: [master]
Воскресенье 18 августа 2024  23:47:12 +0300 (0:00:01.564)       0:02:48.113 *** 
Воскресенье 18 августа 2024  23:47:12 +0300 (0:00:00.030)       0:02:48.144 *** 
Воскресенье 18 августа 2024  23:47:12 +0300 (0:00:00.093)       0:02:48.238 *** 
Воскресенье 18 августа 2024  23:47:12 +0300 (0:00:00.058)       0:02:48.296 *** 
Воскресенье 18 августа 2024  23:47:12 +0300 (0:00:00.070)       0:02:48.367 *** 
Воскресенье 18 августа 2024  23:47:12 +0300 (0:00:00.042)       0:02:48.409 *** 
Воскресенье 18 августа 2024  23:47:13 +0300 (0:00:00.024)       0:02:48.433 *** 
Воскресенье 18 августа 2024  23:47:13 +0300 (0:00:00.023)       0:02:48.457 *** 

TASK [etcd : Gen_certs | check certificate permissions] **************************************************************************************************************
changed: [master]
Воскресенье 18 августа 2024  23:47:13 +0300 (0:00:00.312)       0:02:48.769 *** 

TASK [etcd : Trust etcd CA] ******************************************************************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/etcd/tasks/upd_ca_trust.yml for master
Воскресенье 18 августа 2024  23:47:13 +0300 (0:00:00.037)       0:02:48.806 *** 

TASK [etcd : Gen_certs | target ca-certificate store file] ***********************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:47:13 +0300 (0:00:00.028)       0:02:48.834 *** 

TASK [etcd : Gen_certs | add CA to trusted CA dir] *******************************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:47:13 +0300 (0:00:00.399)       0:02:49.234 *** 
Воскресенье 18 августа 2024  23:47:13 +0300 (0:00:00.021)       0:02:49.256 *** 
Воскресенье 18 августа 2024  23:47:13 +0300 (0:00:00.019)       0:02:49.276 *** 
Воскресенье 18 августа 2024  23:47:13 +0300 (0:00:00.019)       0:02:49.295 *** 
Воскресенье 18 августа 2024  23:47:13 +0300 (0:00:00.024)       0:02:49.320 *** 
Воскресенье 18 августа 2024  23:47:13 +0300 (0:00:00.023)       0:02:49.343 *** 
Воскресенье 18 августа 2024  23:47:13 +0300 (0:00:00.022)       0:02:49.366 *** 
Воскресенье 18 августа 2024  23:47:13 +0300 (0:00:00.030)       0:02:49.397 *** 

TASK [etcdctl_etcdutl : Download etcd binary] ************************************************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/etcdctl_etcdutl/tasks/../../download/tasks/download_file.yml for master
Воскресенье 18 августа 2024  23:47:14 +0300 (0:00:00.032)       0:02:49.429 *** 

TASK [etcdctl_etcdutl : Prep_download | Set a few facts] *************************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:47:14 +0300 (0:00:00.279)       0:02:49.708 *** 

TASK [etcdctl_etcdutl : Download_file | Show url of file to dowload] *************************************************************************************************
ok: [master] => {
    "msg": "https://github.com/etcd-io/etcd/releases/download/v3.5.12/etcd-v3.5.12-linux-amd64.tar.gz"
}
Воскресенье 18 августа 2024  23:47:14 +0300 (0:00:00.501)       0:02:50.210 *** 

TASK [etcdctl_etcdutl : Download_file | Set pathname of cached file] *************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:47:15 +0300 (0:00:00.502)       0:02:50.712 *** 

TASK [etcdctl_etcdutl : Download_file | Create dest directory on node] ***********************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:47:16 +0300 (0:00:01.001)       0:02:51.714 *** 
Воскресенье 18 августа 2024  23:47:16 +0300 (0:00:00.023)       0:02:51.738 *** 
Воскресенье 18 августа 2024  23:47:16 +0300 (0:00:00.028)       0:02:51.766 *** 

TASK [etcdctl_etcdutl : Download_file | Download item] ***************************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:47:19 +0300 (0:00:02.800)       0:02:54.567 *** 
Воскресенье 18 августа 2024  23:47:19 +0300 (0:00:00.021)       0:02:54.588 *** 
Воскресенье 18 августа 2024  23:47:19 +0300 (0:00:00.021)       0:02:54.610 *** 
Воскресенье 18 августа 2024  23:47:19 +0300 (0:00:00.021)       0:02:54.631 *** 

TASK [etcdctl_etcdutl : Download_file | Extract file archives] *******************************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/download/tasks/extract_file.yml for master
Воскресенье 18 августа 2024  23:47:19 +0300 (0:00:00.031)       0:02:54.663 *** 

TASK [etcdctl_etcdutl : Extract_file | Unpacking archive] ************************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:47:22 +0300 (0:00:03.433)       0:02:58.096 *** 

TASK [etcdctl_etcdutl : Copy etcd binary] ****************************************************************************************************************************
changed: [master]
Воскресенье 18 августа 2024  23:47:25 +0300 (0:00:03.002)       0:03:01.099 *** 

TASK [etcdctl_etcdutl : Copy etcdctl and etcdutl binary from download dir] *******************************************************************************************
ok: [master] => (item=etcdctl)
ok: [master] => (item=etcdutl)
Воскресенье 18 августа 2024  23:47:26 +0300 (0:00:00.992)       0:03:02.091 *** 

TASK [etcdctl_etcdutl : Create etcdctl wrapper script] ***************************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:47:27 +0300 (0:00:00.717)       0:03:02.809 *** 

TASK [etcd : Install etcd] *******************************************************************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/etcd/tasks/install_host.yml for master
Воскресенье 18 августа 2024  23:47:27 +0300 (0:00:00.039)       0:03:02.849 *** 

TASK [etcd : Get currently-deployed etcd version] ********************************************************************************************************************
changed: [master]
Воскресенье 18 августа 2024  23:47:27 +0300 (0:00:00.321)       0:03:03.170 *** 
Воскресенье 18 августа 2024  23:47:27 +0300 (0:00:00.025)       0:03:03.196 *** 
Воскресенье 18 августа 2024  23:47:27 +0300 (0:00:00.020)       0:03:03.216 *** 

TASK [etcd : Install | Copy etcd binary from download dir] ***********************************************************************************************************
ok: [master] => (item=etcd)
Воскресенье 18 августа 2024  23:47:28 +0300 (0:00:00.519)       0:03:03.736 *** 

TASK [etcd : Configure etcd] *****************************************************************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/etcd/tasks/configure.yml for master
Воскресенье 18 августа 2024  23:47:28 +0300 (0:00:00.042)       0:03:03.779 *** 

TASK [etcd : Configure | Check if etcd cluster is healthy] ***********************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:47:33 +0300 (0:00:05.313)       0:03:09.093 *** 
Воскресенье 18 августа 2024  23:47:33 +0300 (0:00:00.021)       0:03:09.114 *** 

TASK [etcd : Configure | Refresh etcd config] ************************************************************************************************************************
included: /home/serg/DevOps-35-diplom-yc/kubespray/roles/etcd/tasks/refresh_config.yml for master
Воскресенье 18 августа 2024  23:47:33 +0300 (0:00:00.029)       0:03:09.143 *** 

TASK [etcd : Refresh config | Create etcd config file] ***************************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:47:34 +0300 (0:00:00.712)       0:03:09.856 *** 
Воскресенье 18 августа 2024  23:47:34 +0300 (0:00:00.020)       0:03:09.877 *** 

TASK [etcd : Configure | Copy etcd.service systemd file] *************************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:47:35 +0300 (0:00:00.624)       0:03:10.501 *** 
Воскресенье 18 августа 2024  23:47:35 +0300 (0:00:00.020)       0:03:10.521 *** 

TASK [etcd : Configure | reload systemd] *****************************************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:47:35 +0300 (0:00:00.751)       0:03:11.272 *** 

TASK [etcd : Configure | Ensure etcd is running] *********************************************************************************************************************
ok: [master]
Воскресенье 18 августа 2024  23:47:36 +0300 (0:00:00.750)       0:03:12.023 *** 
Воскресенье 18 августа 2024  23:47:36 +0300 (0:00:00.021)       0:03:12.044 *** 
FAILED - RETRYING: [master]: Configure | Wait for etcd cluster to be healthy (4 retries left).
FAILED - RETRYING: [master]: Configure | Wait for etcd cluster to be healthy (3 retries left).
FAILED - RETRYING: [master]: Configure | Wait for etcd cluster to be healthy (2 retries left).
FAILED - RETRYING: [master]: Configure | Wait for etcd cluster to be healthy (1 retries left).

TASK [etcd : Configure | Wait for etcd cluster to be healthy] ********************************************************************************************************
fatal: [master]: FAILED! => {"attempts": 4, "changed": false, "cmd": "set -o pipefail && /usr/local/bin/etcdctl endpoint --cluster status && /usr/local/bin/etcdctl endpoint --cluster health 2>&1 | grep -v 'Error: unhealthy cluster' >/dev/null", "delta": "0:00:05.031402", "end": "2024-08-18 20:48:31.168928", "msg": "non-zero return code", "rc": 1, "start": "2024-08-18 20:48:26.137526", "stderr": "{\"level\":\"warn\",\"ts\":\"2024-08-18T20:48:31.16624Z\",\"logger\":\"etcd-client\",\"caller\":\"v3@v3.5.12/retry_interceptor.go:62\",\"msg\":\"retrying of unary invoker failed\",\"target\":\"etcd-endpoints://0xc00033d340/10.0.1.13:2379\",\"attempt\":0,\"error\":\"rpc error: code = DeadlineExceeded desc = latest balancer error: last connection error: connection error: desc = \\\"transport: Error while dialing: dial tcp 10.0.1.13:2379: connect: connection refused\\\"\"}\nError: failed to fetch endpoints from etcd cluster member list: context deadline exceeded", "stderr_lines": ["{\"level\":\"warn\",\"ts\":\"2024-08-18T20:48:31.16624Z\",\"logger\":\"etcd-client\",\"caller\":\"v3@v3.5.12/retry_interceptor.go:62\",\"msg\":\"retrying of unary invoker failed\",\"target\":\"etcd-endpoints://0xc00033d340/10.0.1.13:2379\",\"attempt\":0,\"error\":\"rpc error: code = DeadlineExceeded desc = latest balancer error: last connection error: connection error: desc = \\\"transport: Error while dialing: dial tcp 10.0.1.13:2379: connect: connection refused\\\"\"}", "Error: failed to fetch endpoints from etcd cluster member list: context deadline exceeded"], "stdout": "", "stdout_lines": []}

NO MORE HOSTS LEFT ***************************************************************************************************************************************************

PLAY RECAP ***********************************************************************************************************************************************************
master                     : ok=427  changed=10   unreachable=0    failed=1    skipped=502  rescued=0    ignored=0   
worker-1                   : ok=318  changed=4    unreachable=0    failed=0    skipped=402  rescued=0    ignored=0   
worker-2                   : ok=318  changed=4    unreachable=0    failed=0    skipped=398  rescued=0    ignored=0   

Воскресенье 18 августа 2024  23:48:31 +0300 (0:00:54.575)       0:04:06.620 *** 
=============================================================================== 
etcd : Configure | Wait for etcd cluster to be healthy ------------------------------------------------------------------------------------------------------- 54.58s
etcd : Configure | Check if etcd cluster is healthy ----------------------------------------------------------------------------------------------------------- 5.31s
container-engine/validate-container-engine : Populate service facts ------------------------------------------------------------------------------------------- 4.00s
container-engine/containerd : Containerd | Unpack containerd archive ------------------------------------------------------------------------------------------ 3.95s
container-engine/crictl : Extract_file | Unpacking archive ---------------------------------------------------------------------------------------------------- 3.57s
etcdctl_etcdutl : Extract_file | Unpacking archive ------------------------------------------------------------------------------------------------------------ 3.43s
etcdctl_etcdutl : Copy etcd binary ---------------------------------------------------------------------------------------------------------------------------- 3.00s
container-engine/containerd : Download_file | Download item --------------------------------------------------------------------------------------------------- 2.98s
download : Download_file | Download item ---------------------------------------------------------------------------------------------------------------------- 2.96s
container-engine/runc : Download_file | Download item --------------------------------------------------------------------------------------------------------- 2.94s
container-engine/crictl : Download_file | Download item ------------------------------------------------------------------------------------------------------- 2.87s
container-engine/nerdctl : Download_file | Download item ------------------------------------------------------------------------------------------------------ 2.86s
etcdctl_etcdutl : Download_file | Download item --------------------------------------------------------------------------------------------------------------- 2.80s
container-engine/nerdctl : Extract_file | Unpacking archive --------------------------------------------------------------------------------------------------- 2.76s
download : Extract_file | Unpacking archive ------------------------------------------------------------------------------------------------------------------- 2.04s
download : Extract_file | Unpacking archive ------------------------------------------------------------------------------------------------------------------- 1.91s
kubernetes/preinstall : Ensure kubelet expected parameters are set -------------------------------------------------------------------------------------------- 1.72s
etcd : Gen_certs | run cert generation script for etcd and kube control plane nodes --------------------------------------------------------------------------- 1.56s
kubernetes/preinstall : Ensure ping package ------------------------------------------------------------------------------------------------------------------- 1.56s
container-engine/containerd : Containerd | Remove orphaned binary --------------------------------------------------------------------------------------------- 1.52s
```

# В процессе установки возникает ошибка: не запускается сервис `etcd`

```bash
╰─➤systemctl status etcd.service
● etcd.service - etcd
     Loaded: loaded (/etc/systemd/system/etcd.service; enabled; vendor preset: enabled)
     Active: activating (auto-restart) (Result: exit-code) since Sun 2024-08-18 21:00:08 UTC; 6s ago
    Process: 10251 ExecStart=/usr/local/bin/etcd (code=exited, status=1/FAILURE)
   Main PID: 10251 (code=exited, status=1/FAILURE)
```

Журнал ошибки:

```bash
╰─➤udo journalctl -xeu etcd.service
Aug 18 20:51:57 master etcd[9828]: {"level":"info","ts":"2024-08-18T20:51:57.187667Z","caller":"flags/flag.go:113","msg":"recognized and used environment variable","variable-name":"ETCD_ADVERTISE_CLIENT_URLS","variable-value":"https://84.201.172.214:2379"}
Aug 18 20:51:57 master etcd[9828]: {"level":"info","ts":"2024-08-18T20:51:57.187976Z","caller":"flags/flag.go:113","msg":"recognized and used environment variable","variable-name":"ETCD_AUTO_COMPACTION_RETENTION","variable-value":"8"}
Aug 18 20:51:57 master etcd[9828]: {"level":"info","ts":"2024-08-18T20:51:57.187995Z","caller":"flags/flag.go:113","msg":"recognized and used environment variable","variable-name":"ETCD_CERT_FILE","variable-value":"/etc/ssl/etcd/ssl/member-master.pem"}
Aug 18 20:51:57 master etcd[9828]: {"level":"info","ts":"2024-08-18T20:51:57.188007Z","caller":"flags/flag.go:113","msg":"recognized and used environment variable","variable-name":"ETCD_CLIENT_CERT_AUTH","variable-value":"true"}
Aug 18 20:51:57 master etcd[9828]: {"level":"info","ts":"2024-08-18T20:51:57.188021Z","caller":"flags/flag.go:113","msg":"recognized and used environment variable","variable-name":"ETCD_DATA_DIR","variable-value":"/var/lib/etcd"}
Aug 18 20:51:57 master etcd[9828]: {"level":"info","ts":"2024-08-18T20:51:57.18805Z","caller":"flags/flag.go:113","msg":"recognized and used environment variable","variable-name":"ETCD_ELECTION_TIMEOUT","variable-value":"5000"}
Aug 18 20:51:57 master etcd[9828]: {"level":"info","ts":"2024-08-18T20:51:57.188059Z","caller":"flags/flag.go:113","msg":"recognized and used environment variable","variable-name":"ETCD_ENABLE_V2","variable-value":"true"}
Aug 18 20:51:57 master etcd[9828]: {"level":"info","ts":"2024-08-18T20:51:57.188084Z","caller":"flags/flag.go:113","msg":"recognized and used environment variable","variable-name":"ETCD_EXPERIMENTAL_INITIAL_CORRUPT_CHECK","variable-value":"True"}
Aug 18 20:51:57 master etcd[9828]: {"level":"info","ts":"2024-08-18T20:51:57.188105Z","caller":"flags/flag.go:113","msg":"recognized and used environment variable","variable-name":"ETCD_HEARTBEAT_INTERVAL","variable-value":"250"}
Aug 18 20:51:57 master etcd[9828]: {"level":"info","ts":"2024-08-18T20:51:57.188119Z","caller":"flags/flag.go:113","msg":"recognized and used environment variable","variable-name":"ETCD_INITIAL_ADVERTISE_PEER_URLS","variable-value":"https://84.201.172.214:2380"}
Aug 18 20:51:57 master etcd[9828]: {"level":"info","ts":"2024-08-18T20:51:57.188129Z","caller":"flags/flag.go:113","msg":"recognized and used environment variable","variable-name":"ETCD_INITIAL_CLUSTER","variable-value":"etcd1=https://10.0.1.13:2380"}
Aug 18 20:51:57 master etcd[9828]: {"level":"info","ts":"2024-08-18T20:51:57.188139Z","caller":"flags/flag.go:113","msg":"recognized and used environment variable","variable-name":"ETCD_INITIAL_CLUSTER_STATE","variable-value":"new"}
Aug 18 20:51:57 master etcd[9828]: {"level":"info","ts":"2024-08-18T20:51:57.188148Z","caller":"flags/flag.go:113","msg":"recognized and used environment variable","variable-name":"ETCD_INITIAL_CLUSTER_TOKEN","variable-value":"k8s_etcd"}
Aug 18 20:51:57 master etcd[9828]: {"level":"info","ts":"2024-08-18T20:51:57.188177Z","caller":"flags/flag.go:113","msg":"recognized and used environment variable","variable-name":"ETCD_KEY_FILE","variable-value":"/etc/ssl/etcd/ssl/member-master-key.pem"}
Aug 18 20:51:57 master etcd[9828]: {"level":"info","ts":"2024-08-18T20:51:57.188256Z","caller":"flags/flag.go:113","msg":"recognized and used environment variable","variable-name":"ETCD_LISTEN_CLIENT_URLS","variable-value":"https://10.0.1.13:2379,https://127.0.0.1:2379"}
Aug 18 20:51:57 master etcd[9828]: {"level":"info","ts":"2024-08-18T20:51:57.188268Z","caller":"flags/flag.go:113","msg":"recognized and used environment variable","variable-name":"ETCD_LISTEN_PEER_URLS","variable-value":"https://10.0.1.13:2380"}
Aug 18 20:51:57 master etcd[9828]: {"level":"info","ts":"2024-08-18T20:51:57.188292Z","caller":"flags/flag.go:113","msg":"recognized and used environment variable","variable-name":"ETCD_METRICS","variable-value":"basic"}
Aug 18 20:51:57 master etcd[9828]: {"level":"info","ts":"2024-08-18T20:51:57.1883Z","caller":"flags/flag.go:113","msg":"recognized and used environment variable","variable-name":"ETCD_NAME","variable-value":"etcd1"}
Aug 18 20:51:57 master etcd[9828]: {"level":"info","ts":"2024-08-18T20:51:57.18831Z","caller":"flags/flag.go:113","msg":"recognized and used environment variable","variable-name":"ETCD_PEER_CERT_FILE","variable-value":"/etc/ssl/etcd/ssl/member-master.pem"}
Aug 18 20:51:57 master etcd[9828]: {"level":"info","ts":"2024-08-18T20:51:57.188319Z","caller":"flags/flag.go:113","msg":"recognized and used environment variable","variable-name":"ETCD_PEER_CLIENT_CERT_AUTH","variable-value":"True"}
Aug 18 20:51:57 master etcd[9828]: {"level":"info","ts":"2024-08-18T20:51:57.188331Z","caller":"flags/flag.go:113","msg":"recognized and used environment variable","variable-name":"ETCD_PEER_KEY_FILE","variable-value":"/etc/ssl/etcd/ssl/member-master-key.pem"}
Aug 18 20:51:57 master etcd[9828]: {"level":"info","ts":"2024-08-18T20:51:57.18834Z","caller":"flags/flag.go:113","msg":"recognized and used environment variable","variable-name":"ETCD_PEER_TRUSTED_CA_FILE","variable-value":"/etc/ssl/etcd/ssl/ca.pem"}
Aug 18 20:51:57 master etcd[9828]: {"level":"info","ts":"2024-08-18T20:51:57.188365Z","caller":"flags/flag.go:113","msg":"recognized and used environment variable","variable-name":"ETCD_PROXY","variable-value":"off"}
Aug 18 20:51:57 master etcd[9828]: {"level":"info","ts":"2024-08-18T20:51:57.18838Z","caller":"flags/flag.go:113","msg":"recognized and used environment variable","variable-name":"ETCD_SNAPSHOT_COUNT","variable-value":"10000"}
Aug 18 20:51:57 master etcd[9828]: {"level":"info","ts":"2024-08-18T20:51:57.188392Z","caller":"flags/flag.go:113","msg":"recognized and used environment variable","variable-name":"ETCD_TRUSTED_CA_FILE","variable-value":"/etc/ssl/etcd/ssl/ca.pem"}
Aug 18 20:51:57 master etcd[9828]: {"level":"warn","ts":"2024-08-18T20:51:57.188533Z","caller":"embed/config.go:679","msg":"Running http and grpc server on single port. This is not recommended for production."}
Aug 18 20:51:57 master etcd[9828]: {"level":"info","ts":"2024-08-18T20:51:57.188588Z","caller":"etcdmain/etcd.go:73","msg":"Running: ","args":["/usr/local/bin/etcd"]}
Aug 18 20:51:57 master etcd[9828]: {"level":"info","ts":"2024-08-18T20:51:57.188716Z","caller":"etcdmain/etcd.go:116","msg":"server has been already initialized","data-dir":"/var/lib/etcd","dir-type":"member"}
Aug 18 20:51:57 master etcd[9828]: {"level":"warn","ts":"2024-08-18T20:51:57.188773Z","caller":"embed/config.go:679","msg":"Running http and grpc server on single port. This is not recommended for production."}
Aug 18 20:51:57 master etcd[9828]: {"level":"info","ts":"2024-08-18T20:51:57.188786Z","caller":"embed/etcd.go:127","msg":"configuring peer listeners","listen-peer-urls":["https://10.0.1.13:2380"]}
Aug 18 20:51:57 master etcd[9828]: {"level":"info","ts":"2024-08-18T20:51:57.188843Z","caller":"embed/etcd.go:494","msg":"starting with peer TLS","tls-info":"cert = /etc/ssl/etcd/ssl/member-master.pem, key = /etc/ssl/etcd/ssl/member-master-key.pem, client-cert=, client-key=, trusted-ca = /etc/ssl/etcd/ssl/ca.pem, client-cert-auth = true, crl-file = ","cipher-suites":[]}
Aug 18 20:51:57 master etcd[9828]: {"level":"info","ts":"2024-08-18T20:51:57.190517Z","caller":"embed/etcd.go:135","msg":"configuring client listeners","listen-client-urls":["https://10.0.1.13:2379","https://127.0.0.1:2379"]}
Aug 18 20:51:57 master etcd[9828]: {"level":"info","ts":"2024-08-18T20:51:57.190775Z","caller":"embed/etcd.go:308","msg":"starting an etcd server","etcd-version":"3.5.12","git-sha":"e7b3bb6cc","go-version":"go1.20.13","go-os":"linux","go-arch":"amd64","max-cpu-set":2,"max-cpu-available":2,"member-initialized":false,"name":"etcd1","data-dir":"/var/lib/etcd","wal-dir":"","wal-dir-dedicated":"","member-dir":"/var/lib/etcd/member","force-new-cluster":false,"heartbeat-interval":"250ms","election-timeout":"5s","initial-election-tick-advance":true,"snapshot-count":10000,"max-wals":5,"max-snapshots":5,"snapshot-catchup-entries":5000,"initial-advertise-peer-urls":["https://84.201.172.214:2380"],"listen-peer-urls":["https://10.0.1.13:2380"],"advertise-client-urls":["https://84.201.172.214:2379"],"listen-client-urls":["https://10.0.1.13:2379","https://127.0.0.1:2379"],"listen-metrics-urls":[],"cors":["*"],"host-whitelist":["*"],"initial-cluster":"etcd1=https://10.0.1.13:2380","initial-cluster-state":"new","initial-cluster-token":"k8s_etcd","quota-backend-bytes":2147483648,"max-request-bytes":1572864,"max-concurrent-streams":4294967295,"pre-vote":true,"initial-corrupt-check":true,"corrupt-check-time-interval":"0s","compact-check-time-enabled":false,"compact-check-time-interval":"1m0s","auto-compaction-mode":"periodic","auto-compaction-retention":"8h0m0s","auto-compaction-interval":"8h0m0s","discovery-url":"","discovery-proxy":"","downgrade-check-interval":"5s"}
Aug 18 20:51:57 master etcd[9828]: {"level":"info","ts":"2024-08-18T20:51:57.193126Z","caller":"etcdserver/backend.go:81","msg":"opened backend db","path":"/var/lib/etcd/member/snap/db","took":"1.911173ms"}
Aug 18 20:51:57 master etcd[9828]: {"level":"info","ts":"2024-08-18T20:51:57.194048Z","caller":"netutil/netutil.go:112","msg":"resolved URL Host","url":"https://84.201.172.214:2380","host":"84.201.172.214:2380","resolved-addr":"84.201.172.214:2380"}
Aug 18 20:51:57 master etcd[9828]: {"level":"info","ts":"2024-08-18T20:51:57.194084Z","caller":"netutil/netutil.go:112","msg":"resolved URL Host","url":"https://10.0.1.13:2380","host":"10.0.1.13:2380","resolved-addr":"10.0.1.13:2380"}
Aug 18 20:51:57 master etcd[9828]: {"level":"info","ts":"2024-08-18T20:51:57.196832Z","caller":"embed/etcd.go:375","msg":"closing etcd server","name":"etcd1","data-dir":"/var/lib/etcd","advertise-peer-urls":["https://84.201.172.214:2380"],"advertise-client-urls":["https://84.201.172.214:2379"]}
Aug 18 20:51:57 master etcd[9828]: {"level":"info","ts":"2024-08-18T20:51:57.197015Z","caller":"embed/etcd.go:377","msg":"closed etcd server","name":"etcd1","data-dir":"/var/lib/etcd","advertise-peer-urls":["https://84.201.172.214:2380"],"advertise-client-urls":["https://84.201.172.214:2379"]}
Aug 18 20:51:57 master etcd[9828]: {"level":"fatal","ts":"2024-08-18T20:51:57.197049Z","caller":"etcdmain/etcd.go:204","msg":"discovery failed","error":"--initial-cluster has etcd1=https://10.0.1.13:2380 but missing from --initial-advertise-peer-urls=https://84.201.172.214:2380 (resolved urls: \"https://84.201.172.214:2380\" != \"https://10.0.1.13:2380\")","stacktrace":"go.etcd.io/etcd/server/v3/etcdmain.startEtcdOrProxyV2\n\tgo.etcd.io/etcd/server/v3/etcdmain/etcd.go:204\ngo.etcd.io/etcd/server/v3/etcdmain.Main\n\tgo.etcd.io/etcd/server/v3/etcdmain/main.go:40\nmain.main\n\tgo.etcd.io/etcd/server/v3/main.go:31\nruntime.main\n\truntime/proc.go:250"}
Aug 18 20:51:57 master systemd[1]: etcd.service: Main process exited, code=exited, status=1/FAILURE
░░ Subject: Unit process exited
░░ Defined-By: systemd
░░ Support: http://www.ubuntu.com/support
░░ 
░░ An ExecStart= process belonging to unit etcd.service has exited.
░░ 
░░ The process' exit code is 'exited' and its exit status is 1.
Aug 18 20:51:57 master systemd[1]: etcd.service: Failed with result 'exit-code'.
░░ Subject: Unit failed
░░ Defined-By: systemd
░░ Support: http://www.ubuntu.com/support
░░ 
░░ The unit etcd.service has entered the 'failed' state with result 'exit-code'.
Aug 18 20:51:57 master systemd[1]: Failed to start etcd.
░░ Subject: A start job for unit etcd.service has failed
░░ Defined-By: systemd
░░ Support: http://www.ubuntu.com/support
░░ 
░░ A start job for unit etcd.service has finished with a failure.
░░ 
░░ The job identifier is 8164 and the job result is failed.
```

# Пробывал менять дистрибутивы (ubuntu 18.04 20.04 22.04, debian 10 11 12, almalinux 8 и 9, centos 7) и kubespray (2.22.2, 2.23.3, 2.24.0, 2.24.1, 2.24.2 и 2.25.0), но ничего не помогает. Пробывал изменять некоторые переменные, но всё без изменений. Пробывал поднять с помощью терраформа etcd, сервис поднялся, но при повторной конфигурации etcd - K8S сервис падает:

```
#cloud-config
users:
  - name: ubuntu
    groups: sudo
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    ssh_authorized_keys:
      - ${ssh_public_key}
package_update: true
package_upgrade: false
packages:
  - mc
  - git
  - apt-transport-https
  - ca-certificates
  - curl
  - gnupg
  - lsb-release
  - unattended-upgrades

runcmd:
  - curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
  - chmod 700 get_helm.sh
  - ./get_helm.sh
  - mkdir archives
  - cd archives
  - export etcdVersion=v3.5.12
  - wget https://github.com/coreos/etcd/releases/download/$etcdVersion/etcd-$etcdVersion-linux-amd64.tar.gz
  - tar -xvf etcd-$etcdVersion-linux-amd64.tar.gz -C /usr/local/bin/ --strip-components=1
  - cd ..
  - ./create-config.sh etcd
  - systemctl start etcd
```
# Облазил весь интернет, но решения так и не нашел. Как исправить уже не знаю. Может подскажите как можно исправить данную проблему?



















---
---
~~Спустя некоторое время установка Kubernetes кластера методом Kubespray завершена:~~

~~```bash~~
~~╰─➤~~
~~```~~

















































~~![img07.png](img/img07.png)~~

~~Далее нужно создать конфигурационный файл кластера Kubernetes.~~

~~Для этого подключаюсь к Master ноде и выполняем следующие команды:~~

~~![img08.png](img/img08.png)~~

~~Эти команды создают директорию для хранения файла конфигурации, копируют созданный при установке Kubernetes кластера конфигурационный файл в созданную директорию и назначает права для пользователя на директорию и файл конфигурации.~~

~~Конфигурационный файл создан. Теперь можно проверить доступность подов и нод кластера:~~

~~![img09.png](img/img09.png)~~

~~Поды и ноды кластера доступны и находятся в состоянии готовности, следовательно развёртывание Kubernetes кластера успешно завершено.~~






























---
### Создание тестового приложения

Для перехода к следующему этапу необходимо подготовить тестовое приложение, эмулирующее основное приложение разрабатываемое вашей компанией.

Способ подготовки:

1. Рекомендуемый вариант:  
   а. Создайте отдельный git репозиторий с простым nginx конфигом, который будет отдавать статические данные.  
   б. Подготовьте Dockerfile для создания образа приложения.  
2. Альтернативный вариант:  
   а. Используйте любой другой код, главное, чтобы был самостоятельно создан Dockerfile.

Ожидаемый результат:

1. Git репозиторий с тестовым приложением и Dockerfile.
2. Регистри с собранным docker image. В качестве регистри может быть DockerHub или [Yandex Container Registry](https://cloud.yandex.ru/services/container-registry), созданный также с помощью terraform.

### Выполнение этапа "Создание тестового приложения":

1. Создаю отдельный репозиторий для тестового приложения и клонирую репозиторий на свою рабочую машину:

```bash
╰─➤git clone https://github.com/LotsmanSM/DevOps-35-diplom-test-site
Клонирование в «DevOps-35-diplom-test-site»...
warning: Похоже, что вы клонировали пустой репозиторий.
```

Создаю статичную страничку, которая будет показывать картинку и текст:

```
<html>
    <head>
        <title>Tools DevOps</title>
        <meta http-equiv="content-type" content="text/html; charset=UTF-8">
        <meta name="title" content="Tools DevOps">
        <meta name="author" content="Lotsman SM">
        <meta name="description" content="DevOps-Dark">
    </head>
    <body>
        <h1>Tools DevOps</h1>
        <img src="DevOps-Dark.png"/>
    </body>
</html>
```

Сделаю коммит и отправлю созданную страницу в репозиторий:

```bash
╰─➤git status 
Текущая ветка: main

Еще нет коммитов

Неотслеживаемые файлы:
  (используйте «git add <файл>...», чтобы добавить в то, что будет включено в коммит)
	Dockerfile
	README.md
	content/

индекс пуст, но есть неотслеживаемые файлы
(используйте «git add», чтобы проиндексировать их)

╰─➤git add .

╰─➤git commit -m 'add content for site'
[main 5cadfcd] add content for site
 1 file changed, 3 insertions(+), 3 deletions(-)

╰─➤git push 
Перечисление объектов: 7, готово.
Подсчет объектов: 100% (7/7), готово.
При сжатии изменений используется до 8 потоков
Сжатие объектов: 100% (4/4), готово.
Запись объектов: 100% (4/4), 395 байтов | 395.00 КиБ/с, готово.
Всего 4 (изменений 2), повторно использовано 0 (изменений 0), повторно использовано пакетов 0
remote: Resolving deltas: 100% (2/2), completed with 2 local objects.
To https://github.com/LotsmanSM/DevOps-35-diplom-test-site
   539d8ab..5cadfcd  main -> main
```

[Ссылка на репозиторий](https://github.com/LotsmanSM/DevOps-35-diplom-test-site)

2. Создаю новый репозиторий на [hub.docker.com](https://hub.docker.com/repository/docker/lotsmansm/diplom-test-site/general) `lotsmansm/diplom-test-site`

Пишу Dockerfile, который создаст контейнер с nginx и отобразит созданную страницу:

```
FROM nginx:1.27.0
RUN rm -rf /usr/share/nginx/html/*
COPY content/ /usr/share/nginx/html/
EXPOSE 80
```

Авторизуюсь в Docker Hub:

![img10_docker_login.png](img/img10_docker_login.png)

Создаю Docker образ:

```bash
╰─➤docker build -t lotsmansm/diplom-test-site:0.1 .
[+] Building 1.2s (9/9) FINISHED                                                                                                                                      docker:default
 => [internal] load build definition from Dockerfile                                                                                                                            0.0s
 => => transferring dockerfile: 136B                                                                                                                                            0.0s
 => [internal] load metadata for docker.io/library/nginx:1.27.0                                                                                                                 1.2s
 => [auth] library/nginx:pull token for registry-1.docker.io                                                                                                                    0.0s
 => [internal] load .dockerignore                                                                                                                                               0.0s
 => => transferring context: 2B                                                                                                                                                 0.0s
 => [1/3] FROM docker.io/library/nginx:1.27.0@sha256:93db6ea665b5485e59f0b35e506456b5055925d43011bdcc459d556332d231a2                                                           0.0s
 => [internal] load build context                                                                                                                                               0.0s
 => => transferring context: 111B                                                                                                                                               0.0s
 => CACHED [2/3] RUN rm -rf /usr/share/nginx/html/*                                                                                                                             0.0s
 => CACHED [3/3] COPY content/ /usr/share/nginx/html/                                                                                                                           0.0s
 => exporting to image                                                                                                                                                          0.0s
 => => exporting layers                                                                                                                                                         0.0s
 => => writing image sha256:a21abed12e0e11c2e09e920302d7b0ee192cb49ef319def11f2e596ec3e7d07f                                                                                    0.0s
 => => naming to docker.io/lotsmansm/diplom-test-site:0.1                                                                                                                       0.0s

View build details: docker-desktop://dashboard/build/default/default/ipdl89atomaxniyzaj3woiud9
```
Проверю, создался ли образ:

```bash
╰─➤docker images
REPOSITORY                   TAG       IMAGE ID       CREATED          SIZE
lotsmansm/diplom-test-site   0.1       a21abed12e0e   20 minutes ago   188MB
```

Образ создан.

Опубликую созданный образ реестре Docker Hub:

```bash
╰─➤docker push lotsmansm/diplom-test-site:0.1
The push refers to repository [docker.io/lotsmansm/diplom-test-site]
74ae572d8154: Pushed 
23bbd55d15bd: Pushed 
b90d53c29dae: Mounted from library/nginx 
79bfdc61ef6f: Mounted from library/nginx 
0c95345509b7: Mounted from library/nginx 
14dc34bc60ae: Mounted from library/nginx 
45878e4d8341: Mounted from library/nginx 
9aa78b86f4b8: Mounted from library/nginx 
9853575bc4f9: Mounted from library/nginx 
0.1: digest: sha256:fdb5a1bfdf8d588a5bf43e0ae2fcfb6a890e210ce47fb0506117c31ef3933bf6 size: 2195
```

Проверю наличие образа в реестре Docker Hub:

![img11_dockerhub.png](img/img11_dockerhub.png)

[Ссылка на реестр Docker Hub](https://hub.docker.com/repository/docker/lotsmansm/diplom-test-site/general)

Образ опубликован, подготовка тестового приложения закончена.

---
### Подготовка cистемы мониторинга и деплой приложения

Уже должны быть готовы конфигурации для автоматического создания облачной инфраструктуры и поднятия Kubernetes кластера.  
Теперь необходимо подготовить конфигурационные файлы для настройки нашего Kubernetes кластера.

Цель:
1. Задеплоить в кластер [prometheus](https://prometheus.io/), [grafana](https://grafana.com/), [alertmanager](https://github.com/prometheus/alertmanager), [экспортер](https://github.com/prometheus/node_exporter) основных метрик Kubernetes.
2. Задеплоить тестовое приложение, например, [nginx](https://www.nginx.com/) сервер отдающий статическую страницу.

Способ выполнения:
1. Воспользоваться пакетом [kube-prometheus](https://github.com/prometheus-operator/kube-prometheus), который уже включает в себя [Kubernetes оператор](https://operatorhub.io/) для [grafana](https://grafana.com/), [prometheus](https://prometheus.io/), [alertmanager](https://github.com/prometheus/alertmanager) и [node_exporter](https://github.com/prometheus/node_exporter). Альтернативный вариант - использовать набор helm чартов от [bitnami](https://github.com/bitnami/charts/tree/main/bitnami).

2. Если на первом этапе вы не воспользовались [Terraform Cloud](https://app.terraform.io/), то задеплойте и настройте в кластере [atlantis](https://www.runatlantis.io/) для отслеживания изменений инфраструктуры. Альтернативный вариант 3 задания: вместо Terraform Cloud или atlantis настройте на автоматический запуск и применение конфигурации terraform из вашего git-репозитория в выбранной вами CI-CD системе при любом комите в main ветку. Предоставьте скриншоты работы пайплайна из CI/CD системы.

Ожидаемый результат:
1. Git репозиторий с конфигурационными файлами для настройки Kubernetes.
2. Http доступ к web интерфейсу grafana.
3. Дашборды в grafana отображающие состояние Kubernetes кластера.
4. Http доступ к тестовому приложению.


### Выполнение этапа "Подготовка cистемы мониторинга и деплой приложения":





































---
### Установка и настройка CI/CD

Осталось настроить ci/cd систему для автоматической сборки docker image и деплоя приложения при изменении кода.

Цель:

1. Автоматическая сборка docker образа при коммите в репозиторий с тестовым приложением.
2. Автоматический деплой нового docker образа.

Можно использовать [teamcity](https://www.jetbrains.com/ru-ru/teamcity/), [jenkins](https://www.jenkins.io/), [GitLab CI](https://about.gitlab.com/stages-devops-lifecycle/continuous-integration/) или GitHub Actions.

Ожидаемый результат:

1. Интерфейс ci/cd сервиса доступен по http.
2. При любом коммите в репозиторие с тестовым приложением происходит сборка и отправка в регистр Docker образа.
3. При создании тега (например, v1.0.0) происходит сборка и отправка с соответствующим label в регистри, а также деплой соответствующего Docker образа в кластер Kubernetes.

---
## Что необходимо для сдачи задания?

1. Репозиторий с конфигурационными файлами Terraform и готовность продемонстрировать создание всех ресурсов с нуля.
2. Пример pull request с комментариями созданными atlantis'ом или снимки экрана из Terraform Cloud или вашего CI-CD-terraform pipeline.
3. Репозиторий с конфигурацией ansible, если был выбран способ создания Kubernetes кластера при помощи ansible.
4. Репозиторий с Dockerfile тестового приложения и ссылка на собранный docker image.
5. Репозиторий с конфигурацией Kubernetes кластера.
6. Ссылка на тестовое приложение и веб интерфейс Grafana с данными доступа.
7. Все репозитории рекомендуется хранить на одном ресурсе (github, gitlab)

