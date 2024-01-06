# REINICIO AUTOMÁTICO DE SERVIDOR

**IMPORTANTE:** Esto solo lo use en una VPS Ubuntu.

1.- Iniciamos nuestro servidor con la guía de SirPlease.

2.- Nos conectamos a nuestra VPS a travez de PuTTY con usuario root y ejecutamos los siguientes comandos.

    sudo apt-get install htop
	
	htop
	
3.- Nos saldran varios procesos, para ordenarlos presionamos la tecla F5. Despúes en la parte superior derecha en donde dice "Command", en la colummna buscaremos nuestro servidor, una vez ubicado no perdamos la línea y nos iremos hacia la izquierda hasta llegar a la columna llamada PID, en la línea de nuestro servidor estarán unos números el cual sera el PID del proceso de nuestro servidor que es necesario y lo anotamos.

4.- Entramos al archivo check_and_execute.sh y modificamos la línea 4. Cambiamos el PDI por el que obtuvimos anteriormente, guardamos los cambios y cerramos el archivo.

5.- Entramos a nuestro VPS con usuario root a traves de Filezilla y copiamos el archivo check_and_execute.sh en la carpeta /root

6.- Nos conectamos nuevamente a nuestro VPS con usuario root desde PuTTY y colocamos los siguiente comandos.

    chmod +x check_and_execute.sh
	
7.- Probamos el archivo con el siguiente comando, para esto nuestro servidor debe estar apagado.

    ./check_and_execute.sh
	
 Si todo esta bien nos saldra el siguiente mensaje: "El proceso no está en ejecución, ejecutar el comando con privilegios de root"
	
8.- Para configurar que el archivo se ejecute automáticamente ponemos el siguiente comando.

    crontab -e
	
 Se nos abrira un texto, nos desplazamos hasta la ultima línea esta debe estar vacía, si no es el caso presionamos enter y ponemos el siguiente texto.
	
	*/1 * * * * /root/check_and_execute.sh
	
Presionamos Ctrl + X para dejar de editar el archivo, presionamos Y para guardar los cambios y Enter para cerrar el archivo. Ya podemos cerrar PuTTY
	
*Listo, ahora tu servidor se reiniciara automáticamente cada vez que el último jugador se desconecte.*