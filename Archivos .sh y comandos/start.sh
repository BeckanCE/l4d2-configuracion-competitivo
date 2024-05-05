#!/bin/bash

# PID del proceso a verificar
target_pid=1769
process_name="screen"  # Reemplaza con el nombre real del proceso
command_to_execute="/etc/init.d/srcds1 start"    # Reemplaza con el comando que deseas ejecutar como root

# Comprobar si el proceso está en ejecución
if ps -p $target_pid > /dev/null; then
    # El proceso está en ejecución, no es necesario ejecutar el comando
    echo "El proceso con PID $target_pid está en ejecución. No es necesario ejecutar el comando."
else
    # El proceso no está en ejecución, ejecutar el comando con privilegios de root
    echo "El proceso con PID $target_pid no está en ejecución. Ejecutando el comando como root."

    # Comando que se ejecutará con privilegios de root
    sudo $command_to_execute
fi
