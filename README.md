# Pipeline DevSecOps: Checkov, Trivy y ECR con GitHub Actions

## Objetivo
Automatizar la seguridad en cada cambio de código. Cuando hago `git push`, un pipeline analiza la infraestructura y el contenedor antes de publicar nada, y solo sube la imagen a AWS si todo pasa los controles. Para conectarse a AWS no usa claves de acceso: se autentica con OIDC.

## Arquitectura
- **GitHub Actions:** ejecuta el pipeline en cada push a `main`.
- **Checkov:** revisa el Terraform y el Dockerfile buscando malas configuraciones de seguridad.
- **Trivy:** escanea la imagen de contenedor buscando vulnerabilidades HIGH y CRITICAL. Si encuentra alguna con arreglo disponible, el pipeline falla y la imagen no se publica.
- **Amazon ECR:** registro privado de imágenes, cifrado con KMS, con escaneo al subir, tags inmutables y una política que conserva solo las últimas 5 imágenes.
- **OIDC + IAM:** GitHub se identifica ante AWS con un token temporal. El rol solo acepta peticiones de este repositorio y de la rama `main`, y solo puede subir imágenes a este repositorio de ECR. No hay access keys guardadas en ningún lado.
- **App de ejemplo:** un servidor HTTP mínimo en Python (`/` y `/health`), en un contenedor que corre con un usuario sin privilegios.

La infraestructura de AWS (ECR, proveedor OIDC y rol) está definida con **Terraform** en la región `us-east-1`.

## Cómo funciona
1. Un push a `main` dispara el pipeline.
2. **Checkov** analiza el código de Terraform y el Dockerfile.
3. Se construye la imagen.
4. **Trivy** la escanea. Si hay vulnerabilidades graves con arreglo disponible, el pipeline se detiene.
5. Si todo pasa, el job asume el rol de AWS por OIDC, inicia sesión en ECR y sube la imagen etiquetada con el hash del commit.

## Cómo usarlo
Crear la base en AWS:

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Guardar el ARN del rol como secreto del repositorio (`Settings → Secrets and variables → Actions`) con el nombre `AWS_ROLE_ARN`:

```bash
terraform output -raw role_arn
```

Después, cada `git push` a `main` corre el pipeline completo. Para eliminar todo:

```bash
terraform destroy
```

## Resultados

### 1. Despliegue de la base con Terraform
Terraform creó 5 recursos: el repositorio de ECR con su política de ciclo de vida, el proveedor OIDC, el rol de IAM y su política.

<img width="513" height="50" alt="Captura de pantalla de 2026-10-22 18-24-58" src="https://github.com/user-attachments/assets/c7cd2254-d855-4b99-b581-7dd254d716ed" />


### 2. Ejecuciones del pipeline
Los primeros intentos fallaron por distintos motivos (los explico más abajo). El pipeline terminó en verde cuando resolví cada uno.

<img width="1354" height="491" alt="Captura de pantalla de 2026-10-23 19-26-36" src="https://github.com/user-attachments/assets/02222fd8-77db-4fb9-9087-74edebec1f7e" />


### 3. Trivy detectó vulnerabilidades en la imagen
Trivy frenó el pipeline al encontrar tres paquetes vulnerables con arreglo disponible: `msgpack`, `setuptools` y `urllib3`.

<img width="1281" height="783" alt="Captura de pantalla de 2026-10-23 19-15-47" src="https://github.com/user-attachments/assets/10232e26-87e9-48fe-8fdf-d586398f6dac" />


### 4. Pipeline completo en verde
Con la imagen limpia, los dos jobs pasan: el análisis de configuración con Checkov, y el build con escaneo de Trivy y subida a ECR.

<img width="450" height="161" alt="Captura de pantalla de 2026-10-23 19-20-59" src="https://github.com/user-attachments/assets/3efaea9a-ab5a-4cbf-9d37-ba74bb248e48" />


### 5. Imagen publicada en ECR
La de las 19:02 se subió mientras Trivy estaba en modo informativo, para depurar la autenticación. La de las 19:20 es la imagen limpia, publicada con Trivy en modo estricto.

<img width="1493" height="121" alt="IMG-20261023-WA0017" src="https://github.com/user-attachments/assets/296f1ac1-d2ad-4581-80ef-78c4694e2855" />


## Problemas que resolví
- **Versión de una acción que ya no existía:** el pipeline fallaba porque la versión de `trivy-action` que usaba había dejado de estar disponible. Revisé las versiones publicadas y pasé a la 0.35.0, que los mantenedores indican como no comprometida.
- **Error de autenticación OIDC (`Not authorized to perform sts:AssumeRoleWithWebIdentity`):** la política del rol y el secreto estaban bien, así que agregué un paso temporal que mostraba el contenido del token de GitHub. Descubrí que el campo `sub` incluye los IDs numéricos del usuario y del repositorio (`repo:usuario@ID/repo@ID:ref:...`), y mi política esperaba el formato sin IDs. Ajusté la condición del rol en Terraform y funcionó.
- **Vulnerabilidades en la imagen:** la app usa solo la librería estándar de Python, pero la imagen base incluye `pip` y `setuptools`, que arrastraban paquetes vulnerables. Como no se necesitan en producción, los eliminé en el Dockerfile y actualicé los paquetes del sistema. El escaneo pasó limpio y volví Trivy a modo estricto.

## Qué aprendí
- Con OIDC no hay claves de AWS en el repositorio: GitHub recibe credenciales temporales y la política del rol limita qué repositorio y qué rama pueden usarlas.
- Un pipeline de seguridad tiene que fallar cuando encuentra un problema; dejarlo en modo informativo le quita su valor.
- Reducir lo que trae la imagen (menos paquetes) reduce la superficie de ataque y los hallazgos.
- Las acciones de terceros también son una dependencia que puede comprometerse. Como mejora futura, fijaría cada acción por el hash de su commit en lugar de por su versión.

## Costo
Prácticamente cero. GitHub Actions es gratis en repositorios públicos, el rol de IAM y el proveedor OIDC no tienen costo, y ECR cuesta centavos por almacenar una imagen pequeña. Destruí la infraestructura después de las pruebas.
