#!/bin/bash

# Variables de configuración (puedes preconfigurarlas según tus necesidades)
FULL_NAME="User" # Nombre completo del usuario
USERNAME="user" # Nombre de usuario (sin espacios)
PASSWORD="1234" # Contraseña del usuario
DEFAULT_UID="501" # UID para el primer usuario

# Montar el volumen del sistema
SYSTEM_VOLUME="/Volumes/Macintosh HD"
DATA_VOLUME="/Volumes/Macintosh HD - Data"
dscl_path="$DATA_VOLUME/private/var/db/dslocal/nodes/Default"
localUserDirPath="/Local/Default/Users"

# Crear el archivo para evitar el asistente de configuración
touch "$DATA_VOLUME/private/var/db/.AppleSetupDone"

# Crear usuario si no existe
if ! dscl -f "$dscl_path" localhost -list "$localUserDirPath" UniqueID | grep -q "\<$DEFAULT_UID\>"; then
    echo "Creando usuario $USERNAME..."
    dscl -f "$dscl_path" localhost -create "$localUserDirPath/$USERNAME"
    dscl -f "$dscl_path" localhost -create "$localUserDirPath/$USERNAME" UserShell "/bin/zsh"
    dscl -f "$dscl_path" localhost -create "$localUserDirPath/$USERNAME" RealName "$FULL_NAME"
    dscl -f "$dscl_path" localhost -create "$localUserDirPath/$USERNAME" UniqueID "$DEFAULT_UID"
    dscl -f "$dscl_path" localhost -create "$localUserDirPath/$USERNAME" PrimaryGroupID "20"
    mkdir "$DATA_VOLUME/Users/$USERNAME"
    dscl -f "$dscl_path" localhost -create "$localUserDirPath/$USERNAME" NFSHomeDirectory "/Users/$USERNAME"
    dscl -f "$dscl_path" localhost -passwd "$localUserDirPath/$USERNAME" "$PASSWORD"
    dscl -f "$dscl_path" localhost -append "/Local/Default/Groups/admin" GroupMembership "$USERNAME"
    echo "Usuario $USERNAME creado con éxito."
else
    echo "Usuario $USERNAME ya existe."
fi

# Bloquear dominios de MDM (opcional)
# echo "Bloqueando dominios de MDM..."
# echo "0.0.0.0 deviceenrollment.apple.com" >> "$SYSTEM_VOLUME/etc/hosts"
# echo "0.0.0.0 mdmenrollment.apple.com" >> "$SYSTEM_VOLUME/etc/hosts"

echo "Preconfiguración completada. Puedes reiniciar el sistema."
