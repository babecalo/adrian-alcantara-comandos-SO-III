echo "Esto es protect un script que automatiza todo el proceso de la seguridad iniciar de un server "

echo "recuerda que debe ejecutar el script como sudo o superusuario para que pueda funcionar!!! "

echo "primero comprueba cual es la distro que tienes"
echo ""
echo "ingrese 1 --> (Para Debian)"
echo "ingrese 2 --> (Para Redhat)"
read distro

if [ "$distro" = "1" ]; then
	echo "actualizando sistema"
	apt update -y && apt upgrade -y
	clear
	echo "actualizacion exitosa"
	
	echo " Vamos a configurar las reglas de firewalls pero primero "
	echo -e " Elige 1 --> para ufw\n (esto tiene como ventaja la facilidad de ejecucion por lo cual y quieres cambiar algo se te facilitara)\n Elige 2 --> para iptables\n (Con este tienes sumo control de todo)  "

	read fire

	if [ "$fire" = "1" ]; then
		if command -v ufw >/dev/null 2>&1; then
			echo "La aplicacion esta descargada comenzando la configuracion"
			ufw default deny incoming
			ufw default allow outgoing
			ufw allow 22
			ufw limit 22/tcp
			ufw limit ssh/tcp
			ufw enable
			ufw verbose
			
			clear
			echo "----------------------------"
			echo "Configuracion finalizada"
			
		else
			echo -e "La aplicacion no esta descargada\n Descargando"
			apt install ufw -y
			
			echo -e "--- DESCARGA COMPLETA ---\n Comenzando comfiguracion"
			ufw default deny incoming
            ufw default allow outgoing
            ufw allow 22
            ufw limit 22/tcp
            ufw limit ssh/tcp
            ufw enable
            ufw verbose
			
			clear
			echo "----------------------------"
			echo "Configuracion finalizada" 
		fi
#la otra pocion del firewall
	elif [ "$fire" = "2" ]; then
		
		echo "Configurando reglas"
		
		iptables -A INPUT -i lo -j ACCEPT
		iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
		iptables -A INPUT -p tcp --dport 22 -j ACCEPT
		iptables -P INPUT DROP

		clear
		echo "----------------------------"
		echo "Configuracion finalizada"

	else
		echo "Opcion no disponible"
		exit 1
	fi

	echo "----------------------------"

	ssh="/etc/ssh/sshd_config"

	echo "Creando una copia de seguridad de tu archivo /etc/ssh/sshd_config"

	cp "$ssh" "$ssh.bak"

	sed -i "s/^#*PermitRootLogin.*/PermitRootLogin no/" $ssh

	systemctl restart ssh
	echo "ssh asegurado"
	clear
	
#la parte de la configuracion de fail2ban 

	echo "----------------------------"
	echo "Descargando Fail2ban"

	apt install fail2ban -y

	cp "/etc/fail2ban/jail.conf" "/etc/fail2ban/jail.local"

	echo -e "ingrese cuanto tiempo quieres que dure el baneo\n Para segundos son s (eje: 10s).\n Para minutos son m (eje: 10m).\n para horas son h (eje: 10h)."
	read ban
	echo "Ingrese la cantidad de intentos disponible"
	read can
	echo -e "Ingrese cual es el limite de tiempo que se tiene por intento antes de que se reinicie la cuentas para el baneo\n Para segundos son s (eje: 10s).\n Para minutos son m (eje: 10m).\n para horas son h (eje: 10h)"
	read tiepo


	sed -i 's/^bantime\s*=.*/bantime  = $ban/' "/etc/fail2ban/jail.local"
	sed -i 's/^findtime\s*=.*/findtime  = $tiepo/' "/etc/fail2ban/jail.local"
	sed -i 's/^maxretry\s*=.*/maxretry = $can/' "/etc/fail2ban/jail.local"

	echo "Reiniciando el servicio"

	systemctl restart fail2ban

	echo -e "--- TODO COMPLETADO---\n ya puedes usar tu server seguramente"
	exit 0
# Esta es la parte de RedHat
elif [ "$distro" = "2" ]; then
	echo "Actualizando el sistema"
	dnf update -y && dnf upgrade -y
	clear
	echo "actualizacion exitosa"

	echo " Vamos a configurar las reglas de firewalls pero primero "
	echo -e " Elige 1 --> para firewalld\n (esto tiene como ventaja la facilidad de ejecucion por lo cual y quieres cambiar algo se te facilitara)\n Elige 2 --> para nftables\n (Con este tienes sumo control de todo)  "

	read fire

	if [ "$fire" = "1" ]; then
		echo "Configurando las reglas"
		
		firewall-cmd --permanent --zone=public --set-target=DROP
		firewall-cmd --permanent --zone=trusted --add-interface=lo
		firewall-cmd --permanent --zone=public --add-service=ssh
		firewall-cmd --reload
		clear
		
		echo "Firewall configurado exitosamente"

	elif [ "$fire" = "2" ]; then
		echo "Desactivando firewalld"
		systemctl stop firewalld
		systemctl disable firewalld
		echo "___________________________"
		echo "Vamos a enmascarar a firewalld\n para que ningun otro proceso\n lo active y valla a dar error todo"
		echo "___________________________"
		systemctl mask firewalld

		echo "TERMINADO"
		
		echo "configurando nftables"
		sytemctl enable --now nftables
		#nos falta crear las tablas y reglas de todo
		echo "Creando tablas...\n como quieres que se llame tu nueva tabla"
		read "tabla"
		nft add table inet "$tabla"
		nft add chain inet "$tabla" entrada { type filter hook input priority 0 \; polity drop \; }
		nft add rules inet "$tabla" entrada iif lo accept
		nft add rules inet "$tabla" entrada ct state astablished,related accept
		nft add rules inet "$tabla" entrada tcp dport 22 accept
		nft list ruleset > /etc/sysconfig/nftables.conf

		echo "Recargando reglas"
		sudo systemctl reload nftables

		clear
		
	else
		echo "Esta opcion no esta encontrada"
		exit 1
	fi
	echo "----------------------------"

	echo "Asegurando el ROOT por ssh"
	
	ssh="/etc/ssh/sshd_config"

	echo "Creando una copia de seguridad de tu archivo /etc/ssh/sshd_config"

	cp "$ssh" "$ssh.bak"

	sed -i "s/^#*PermitRootLogin.*/PermitRootLogin no/" $ssh

	systemctl restart ssh
	echo "ssh asegurado"

	clear

	echo "----------------------------"
	echo "Descargando Fail2ban"

	dnf install epel-release
	dnf install fail2ban fail2ban-firewalld -y
	systemctl enable --now fail2ban

	cp "/etc/fail2ban/jail.conf" "/etc/fail2ban/jail.local"

	echo -e "ingrese cuanto tiempo quieres que dure el baneo\n Para segundos son s (eje: 10s).\n Para minutos son m (eje: 10m).\n para horas son h (eje: 10h)."
	read ban
	echo "Ingrese la cantidad de intentos disponible"
	read can
	echo -e "Ingrese cual es el limite de tiempo que se tiene por intento antes de que se reinicie la cuentas para el baneo\n Para segundos son s (eje: 10s).\n Para minutos son m (eje: 10m).\n para horas son h (eje: 10h)"
	read tiepo

	#esas \s*=.* sirve para asegurarse al full de los espacios 

	sed -i 's/^bantime\s*=.*/bantime  = $ban/' "/etc/fail2ban/jail.local"
	sed -i 's/^findtime\s*=.**/findtime  = $tiepo/' "/etc/fail2ban/jail.local"
	sed -i 's/^maxretry\s*=.*/maxretry = $can/' "/etc/fail2ban/jail.local"
	sed -i 's/^banaction\s*=.*/banaction = firewallcmd-ipset' "/etc/fail2ban/jail.local"
	sed -i 's/^backend\s*=.*/backend = systemd' "/etc/fail2ban/jail.local"
	
	echo "Reiniciando el servicio"

	systemctl restart fail2ban

	echo -e "--- TODO COMPLETADO---\n ya puedes usar tu server seguramente"
	exit 0
else
	echo "opcion no encontrada"
	exit 1
fi
done
