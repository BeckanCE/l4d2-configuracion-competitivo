#!/bin/bash

# Rutas locales y remotas
local_folder="/home/steam/Steam/steamapps/common/l4d2/left4dead2/demos"
remote_folder="/var/www/html/demos"

# Detalles de la conexión SFTP
hostname="161.132.47.214"
port="22"  # Puerto por defecto para SFTP es 22
username="root"
password="2357"

# Subir cada archivo de la carpeta local a la carpeta remota
for file in "$local_folder"/*; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        echo "Subiendo archivo $filename a $remote_folder en $hostname"
        sshpass -p "$password" sftp -oPort="$port" "$username"@"$hostname" <<EOF
            put "$file" "$remote_folder/$filename"
            bye
EOF
    fi
done