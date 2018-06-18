#deploy con ansistrano


### vault

*  actualizar los roles 
```
cd .ansistrano
ansible-galaxy install -r requirements.yml --force
```

*  antes de poner nada en producion, encriptar los passwords
```
cd .ansistrano
ansible-vault encrypt vars/secret.yml --vault-password-file vault_pass
```

* para provisionar la maquina virtual
```
# desde la raiz del proyecto

vagrant up 
vagrant up preproduction 
```

* para provisionar el entorno de producción

como el proceso de provisionamiento, necesita que nuestro dominio sea publico para configurar los certificados (letsencrypt)
en producción los pasos cambian:

a)   crear el droplet (sin provisionar)

```
#desde la raiz del proyecto
vagrant up --no-provision production
 
```

b) configurar las dns de nuestro dominio, para que apunten al droplet recien creado

c) provisionar el droplet


```
#desde la raiz del proyecto
vagrant provision production
 
```


* para hacer un deploy

```
cd .ansistrano
ansible-playbook deploy.yml --limit preproduction
ansible-playbook deploy.yml --limit production
 
```


* para hacer un rolback

```
cd .ansistrano
ansible-playbook rolback.yml --limit preproduction
ansible-playbook rolback.yml --limit production
 
```
