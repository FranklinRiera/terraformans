# **GCP**: deploying an HTTP App via Terraform + Ansible

## Objectives

- Learn about **IaC: Terraform**
- Learn about Deploying GCP VM instances with Terraform
- Learn about **Ansible**

## [IaaC: Terraform](https://terraform.io)

Terraform is an IaaC tool, used primarily by DevOps teams to automate various infrastructure tasks. The provisioning of cloud resources, for instance, is one of the main use cases of Terraform. It's a cloud-agnostic, open-source provisioning tool written in the Go language and created by HashiCorp.

> *Terraform is an infrastructure as code tool that enables you to safely and predictably provision and manage infrastructure in any cloud.*

- [What is Infrastructure as Code with Terraform?](https://developer.hashicorp.com/terraform/tutorials/gcp-get-started/infrastructure-as-code)

![](https://developer.hashicorp.com/_next/image?url=https%3A%2F%2Fcontent.hashicorp.com%2Fapi%2Fassets%3Fproduct%3Dtutorials%26version%3Dmain%26asset%3Dpublic%252Fimg%252Fterraform%252Fterraform-iac.png%26width%3D2400%26height%3D870&w=3840&q=75)

## [Ansible](https://www.ansible.com/)

Ansible® is an open source, command-line IT automation software application written in Python. It can configure systems, deploy software, and orchestrate advanced workflows to support application deployment, system updates, and more.

![](https://miro.medium.com/v2/resize:fit:1100/format:webp/1*8H4XYCNV-xamG0joz22apQ.png)

- [Ansible 101 Getting Started](https://medium.com/@wintonjkt/ansible-101-getting-started-1daaff872b64)
- [Ansible community documentation](https://docs.ansible.com/?extIdCarryOver=true&intcmp=7013a0000034dzKAAQ&percmp=7013a000002i5nEAAQ&sc_cid=701f2000001OH7EAAW)

## Deploying a GCP VM debian-based
### 1. Install Terraform

Based on your OS, follow the [Install Terraform instructions](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) and verify the installation.

### 2. Create a [GCP service account key](https://console.cloud.google.com/apis/credentials/serviceaccountkey)
Create a service account key to enable Terraform to access your GCP account. When creating the key, use the following settings:

- Select "IAM & Admin"
- Select "Service Accounts"
- Click "Create Service Account"
- Give it any name you like and click "Create"
- For the Role, choose "Project -> Editor", then click "Continue"
- Skip granting additional users access, and click "Done"

After you create your service account, download your service account key.

- Select your service account from the list
- Select the "Keys" tab
- In the drop down menu, select "Create new key"
- Leave the "Key Type" as JSON
- Click "Create" to create the key and save the key file to your system

### 3. Create a Public/Private key

This key will be used for SSH access (replace `user` with your username, *e.g., diego.monterob = diego_monterob*):

```bash
ssh-keygen -t rsa -N "" -f user@ucuenca.edu.ec -C user@ucuenca.edu.ec
```

Two files must be created:
- **user@ucuenca.edu.ec**: private key, used for SSH login
- **user@ucuenca.edu.ec.pub**: public key, used for GCP VM configuration

```bash
ls -l user@ucuenca.edu.ec*
-rw------- 1 diego diego 2610 Nov 29 15:07 user@ucuenca.edu.ec
-rw-r--r-- 1 diego diego  573 Nov 29 15:07 user@ucuenca.edu.ec.pub
```

### 4. Create Terraform project

Create a new directory and change into it:

 ```bash
 mkdir terraform-gcp
 cd terraform-gcp
 ```

 Terraform loads all files ending in `.tf` or `.tf.json` in the working directory. Create a `main.tf` file for your configuration.

 ```bash
touch main.tf
```

Open `main.tf` in your text editor, and paste in the configuration below. Be sure to replace `<NAME>` with the path to the service account key file you downloaded and `<PROJECT_ID>` with your project's ID, `<USER>` with your ucuenca user (replace the . with \_), `<PUB-KEY>` with `user@ucuenca.edu.ec.pub` and save the file.

```yaml
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "5.7.0"
    }
  }
}

provider "google" {
  credentials = file("<NAME>.json")

  project = "<PROJECT_ID>"
  region  = "us-central1"
  zone    = "us-central1-c"
}

resource "google_compute_network" "vpc_network" {
  name = "terraform-network"
  auto_create_subnetworks = false
  mtu                     = 1460
}

resource "google_compute_subnetwork" "default" {
  name          = "my-custom-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = "us-central1"
  network       = google_compute_network.vpc_network.id
}

resource "google_compute_firewall" "gcp_firewall" {
  name    = "test-firewall"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "5000", "22"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_instance" "vm_instance" {
  name         = "terraform-instance"
  machine_type = "f1-micro"
  tags         = ["web"]

  metadata = {
    ssh-keys = "<USER>:${file("<PUB-KEY>")}"
  }

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    #    network = google_compute_network.vpc_network.name
    subnetwork = google_compute_subnetwork.default.id
    access_config {
    }
  }
}

output "public_ip" {
  value = google_compute_instance.vm_instance.network_interface.0.access_config.0.nat_ip
  description = "The public IP address of the newly created instance"
}

```

#### Initialize the directory
When you create a new configuration, you need to initialize the directory with terraform init. This step downloads the providers defined in the configuration.

Initialize the directory:

```bash
terraform init
```

#### Format and validate the configuration

The terraform fmt command automatically updates configurations in the current directory for readability and consistency.

Format your configuration. Terraform will print out the names of the files it modified, if any. In this case, your configuration file was already formatted correctly, so Terraform won't return any file names.

```bash
terraform fmt
```

You can also make sure your configuration is syntactically valid and internally consistent by using the `terraform validate` command.

```bash
terraform validate
```

#### Create the infrastructure

Apply the configuration now with the `terraform apply` command. 

```bash
terraform apply
```

Terraform will indicate what infrastructure changes it plans to make, and prompt for your approval before it makes those changes.

This output shows the execution plan, describing which actions Terraform will take in order to create infrastructure to match the configuration. 

Terraform will now pause and wait for approval before proceeding. If anything in the plan seems incorrect or dangerous, it is safe to abort here with no changes made to your infrastructure.

In this case the plan looks acceptable, so type yes at the confirmation prompt to proceed. It may take a few minutes for Terraform to provision the network.

#### Inspect state 

When you applied your configuration, Terraform wrote data into a file called `terraform.tfstate`. Terraform stores the IDs and properties of the resources it manages in this file, so that it can update or destroy those resources going forward.

The Terraform state file is the only way Terraform can track which resources it manages, and often contains sensitive information, so you must store your state file securely and distribute it only to trusted team members who need to manage your infrastructure. 

Inspect the current state using `terraform show`:

```bash
terraform show
```

### 5. SSH access

- Obtain the Public IP of your instance:
```bash
terraform output
public_ip = "35.222.154.158"
```
- Access the VM:
```bash
ssh -i user@ucuenca.edu.ec user@35.222.154.158
```
- Exit the SSH session


## Configuring the HTTP App

The objective is to use Ansible to remotely configure the HTTP App.

### 1. Install Ansible

Based on your OS, follow the [Install Ansible instructions](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#installing-and-upgrading-ansible). For Debian/Ubuntu:

```bash
apt update
apt install ansible
```

### 2. Create Ansible project

Create a new directory and change into it:

 ```bash
 mkdir ansible-gcp
 cd ansible-gcp
 ```

Create a playbook file `nginxgunicornflask.yml` file for your configuration.

 ```bash
touch nginxgunicornflask.yml
```

Open `nginxgunicornflask.yml` in your text editor, and paste in the configuration below. 

```yaml
- name: nginx gunicorn flask
  hosts: webservers
    #  connection: local
  become: true

  vars:
    LOCAL_PROJECT_HOME: "./myproject"
    PROJECT_HOME: "/opt/myproject"
    PROJECT_VENV: "myprojectvenv"
    MAIN_PY: "myproject.py"
    MAIN_SOCK: "myproject.sock"
    NGINX_PORT: 80
    PORT: 5000

  tasks:
  - name: apt install required packages
    apt:
      update_cache: yes
      name:
        - wget
        - curl 
        - python3-pip
        - python3-dev
        - nginx
        - python3-venv        
      state: present

  - name: Create remote directory
    file: path={{PROJECT_HOME}} state=directory

  - name: Copy project code to website server
    copy: src={{item}} dest={{PROJECT_HOME}}
    with_fileglob:
     - "{{LOCAL_PROJECT_HOME}}/*"

  - name: Install reqs into the specified virtualenv using Python3
    ansible.builtin.pip:
      requirements: "{{ PROJECT_HOME }}/requirements.txt"
      virtualenv: "{{ PROJECT_HOME }}/{{ PROJECT_VENV }}"
      virtualenv_command: "python3 -m venv"

  - name: delete a file (or symlink) if it exists
    file:
      path: "/etc/nginx/sites-enabled/default"
      state: absent        

  - name: nginx.conf config file
    template:
      src: "nginx.conf.j2"
      dest: "/etc/nginx/sites-available/myproject"

  - name: create a symlink if it doesn't exist
    file:
      src: "/etc/nginx/sites-available/myproject"
      dest: "/etc/nginx/sites-enabled/myproject"
      state: link

  - name: Create myproject service
    template:
      src: "myproject.service.j2"
      dest: "/etc/systemd/system/myproject.service"

  - name: Reload the SystemD to re-read configurations
    systemd:
      daemon-reload: yes
  
  - name: Enable the myproject service and start
    systemd:
      name: '{{ item }}.service'
      enabled: yes
      state: started
    loop:
      - myproject

  - name: restart nginx service
    systemd:
      name: nginx
      state: restarted
```

Create an `inventory.txt` file with the following:

```bash
webservers:
  hosts:
    web1:
      ansible_port: 22
      ansible_host: <PUBLIC-IP>
      ansible_user: "<USER>"
      ansible_ssh_private_key_file: "<PRIVATE-KEY>"
```

Create a `myproject` directory with the following files:

- `myproject.py`


```python
from flask import Flask
app = Flask(__name__)

@app.route("/")
def hello():
    return "<h1 style='color:blue'>Hello There!</h1>"

if __name__ == "__main__":
    app.run(host='0.0.0.0')
```

- `wsgi.py`

```python
from myproject import app

if __name__ == "__main__":
    app.run()
```

- `requirements.txt`

```bash
wheel
gunicorn
flask
```

Create a `templates` directory with the following files:

- `myproject.service.j2`

```bash
[Unit]
Description=Gunicorn instance to serve myproject
After=network.target

[Service]
User=root
Group=www-data
WorkingDirectory={{ PROJECT_HOME }}
Environment="PATH={{ PROJECT_HOME }}/{{ PROJECT_VENV }}/bin"
ExecStart={{ PROJECT_HOME }}/{{ PROJECT_VENV }}/bin/gunicorn --workers 3 --bind unix:{{ MAIN_SOCK }} -m 007 wsgi:app

[Install]
WantedBy=multi-user.target
```

- `nginx.conf.j2`

```bash
server {
    listen {{ NGINX_PORT }};

    location / {
        include proxy_params;
        proxy_pass http://unix:{{PROJECT_HOME }}/myproject.sock;
    }
}
```

#### Execute the Ansible playbook

```bash
ansible-playbook nginxgunicornflask.yml -i inventory.yml
```

### 3. Verify the HTTP APP

```bash
curl http://<PUBLIC-IP>
<h1 style='color:blue'>Hello There!</h1>% 
```

## Destroy All the GCP resources

To clean all the GCP resources

- Go to the directory `terraform-gcp`
- Execute `terraform destroy`
- Accept the changes with `yes`

```bash
...
Do you really want to destroy all resources?
  Terraform will destroy all your managed infrastructure, as shown above.
  There is no undo. Only 'yes' will be accepted to confirm.

  Enter a value: yes
```
