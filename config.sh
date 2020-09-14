
#!/bin/bash
Menu()
{
echo "---------------------------------------------"
echo "1. Ajouter un utilisateur en tant que sudoer"
echo "2. Configurer les cartes virtuelles"
echo "3. Installer un service DHCP"
echo " "
echo "4. Installer un service DNS"
echo "	4.1. Ajouter un enregistrement DNS"
echo "	4.2. Supprimer un enregistrement DNS"
echo " "
echo "5. BACK-UP (reset)"
echo "---------------------------------------------"
}

sudoer()
{
	echo '*****Utilisateur à mettre en sudo:*****'
	read username
	sudo usermod -aG sudo $username
	Menu
	read choice
}
Cartes()
{
	ip a | grep ens 
	echo '*****insérer la carte a configuré:*****'
	read carte1
	echo auto $carte1 >> /etc/network/interfaces
	echo '*****static ou dhcp?*****'
	read type 
if [ $type = "static" ]
then
	echo iface $carte1 inet $type  >> /etc/network/interfaces
elif [ $type = "dhcp" ]
then
	echo iface $carte1 inet $type  >> /etc/network/interfaces
fi
	echo "*****Adresse IP de la machine? (indiquez le CIDR)*****"
	read ip_adress
	echo address $ip_adress >> /etc/network/interfaces
	systemctl restart networking.service

echo "*****Voulez-vous configurer une autre carte?(y/n)*****"
read choice2

if [ $choice2 = "y" ]
then
	Cartes
elif [ $choice2 = "n" ]
then
	Menu
	read choice
fi
}


dhcp()
{
	apt-get -y install isc-dhcp-server
	rm /etc/dhcp/dhcpd.conf
	touch dhcpd.conf
	echo "*****indiquez le sous-réseau:*****"
	read subnet
	echo "*****indiquez le masque de sous-réseau:*****"
	read net_mask
	echo "*****Indiquez le start range:*****"
	read range_start
	echo "*****Indiquez le end range:*****"
	read range_end
	echo "*****Indiquez l'adresse DNS*****"
	read dns_ip
	echo "*****Indiquez l'adresse du routeur:*****"
	read router_ip


	sed -i -e "s/ip_address/$subnet/g" -e "s/net_mask/$net_mask/g" dhcpd.conf
	sed -i -e "s/range_start/$range_start/g" -e "s/range_end/$range_end/g" dhcpd.conf
	sed -i -e "s/dns_ip/$dns_ip/g" -e "s/router_ip/$router_ip/g" dhcpd.conf

	mv dhcpd.conf /etc/dhcp/

	echo "*****Sur quelle carte Voulez-vous que le dhcp soit connecté?*****"
	echo " "
	ip a | grep ens

	read dhcp_listen

	sed -i -e 's/4=""/"$dhcp_listen"/g' /etc/default/isc-dhcp-server

	systemctl restart isc-dhcp-server

	echo "*********************************************"
	echo "*************** DHCP CONFIGURÉ ***************"
	echo "*********************************************"

	Menu
	read choice

}

dns()
{
	apt-get install -y bind9 bind9utils
	echo "*****Nom de domaine?:*****"
	read dns_name
	echo "zone $dns_name { type master; file '/etc/bind/db.$dns_name'; };" >> /etc/bind/named.conf.local
	cp /etc/bind/db.empty /etc/bind/db.$dns_name
	sed -i -e 's/localhost./$dns_name./g' /etc/bind/db.$dns_name
	sed -i -e 's/root.localhost./root.$dns_name./g' /etc/bind/db.$dns_name
	sed -i -e 's/@	IN 	NS 	$dns_name./" "/g' /etc/bind/db.$dns_name
	echo "$dns_name. IN 	NS 	ns.$dns_name." >> /etc/bind/db.$dns_name
	echo "*****Adresse IP du DNS hôte?:*****"
	read dns_ip_hote
	echo "ns	 IN 	A 	$dns_ip_hote" >> /etc/bind/db.$dns_name
	echo 'options { directory "/var/cache/bind";' > /etc/bind/named.conf.options
	echo ' ' >> /etc/bind/named.conf.options
	echo 'multiple' >> etc/bind/named.conf.options
	echo 'allow-recursion { any; }; forwarders { 8.8.8.8; }; dnssec-enable no; dnssec-validation no; auth-nxdomain no; listen-on-v6 { any; }; listen-on { any; }; allow-query { any; }; };' >> /etc/bind/named.conf.options
	sudo named-checkconf
	sudo named-checkzone $dns_name /etc/bind/db.$dns_name
	systemctl restart bind9

	echo "*********************************************"
	echo "*************** DNS CONFIGURÉ ***************"
	echo "*********************************************"

	Menu 
	read choice

}

enregistrement()
{
	echo "*****FQDN?:*****"
	read fqdn
	echo "*****Type d'enregistrement (A/CNAME/MX/TXT)*****"
	read type_enregistrement
	echo "*****Adresse IP*****"
	read ip_enregistrement

	echo "$fqdn	 IN 	$type_enregistrement 	$ip_enregistrement" >> /etc/bind/db.$dns_name

	echo "***** enregistrement enregistré*****"
	echo " "
	echo "*****Voulez-vous ajouter un autre enregistrement? (y/n) *****"
	read retry_enregistrement
	if [ retry_enregistrement = 'y' ]
	then
		enregistrement
	elif [ retry_enregistrement = 'n' ]
	then 
		Menu
		read choice
	fi
}

sup_enregitrement()
{
	echo "*****1. Supprimer un enregistrement à partir d'une adresse IP? *****"
	echo "*****2. Supprimer un enregistrement à partir d'un FQDN? *****"
	echo "*****3. Supprimer un enregistrement à partir d'un type d'enregistrement? *****"
	echo " "
	echo "*****4. Revenir en arrière *****"
	read choice_sup

	if [ $choice_sup = '1' ]
	then
		echo "***** Indiquez l'adresse IP *****"
		read sup_ip
		sed -i -e 's/$fqdn	 IN 	$type_enregistrement 	$sup_ip/" "/g' /etc/bind/db.$dns_name
		echo "***** DONE *****"
		Menu
		read choice
	elif [ $choice_sup = 2 ]
	then 
		echo "***** Indiquez le FQDN *****"
		read sup_fqdn
		sed -i -e 's/$sup_fqdn	 IN 	$type_enregistrement 	$ip_enregistrement/" "/g' /etc/bind/db.$dns_name
		echo "***** DONE *****"
		Menu
		read choice
	elif [ $choice_sup = 3 ]
	then
		echo "***** Indiquez le type d'enregistrement *****"
		read sup_enregistrement
		sed -i -e 's/$fqdn	 IN 	$sup_enregistrement 	$ip_enregistrement/" "/g' /etc/bind/db.$dns_name
		echo "***** DONE *****"
		Menu
		read choice
	elif [ $choice_sup = 4 ]
	then
		Menu 
		read choice
	fi
}

reset()
{
	echo "********1. BACK-UP DHCP*************"
	echo "********2. BACK-UP DNS**************"

	read choice_reset

	if [ $choice_reset = 1 ]
	then
		apt-get remove --purge -y isc-dhcp-server

	elif [ $choice_reset = 2 ]
	then
		apt-get remove --purge -y bind9
	fi

	Menu
	read choice
}






Menu
read choice
#-----------------sudo user------------------------#
if [ $choice = 1 ]
then
	sudoer

fi
#-----------------config cartes--------------------#
if [ $choice = 2 ]
then
	Cartes
fi

#------------------Installer un serveur DHCP-----------#
if [ $choice = 3 ]
then
	dhcp
fi
#------------------Installer un serveur DNS-----------#

if [ $choice = 4 ]
then
	dns
fi

if [ $choice = '4.1' ]
then
	enregistrement
fi

if [ $choice = '4.2' ]
then
	sup_enregitrement
fi

#------------------BACK-UP-----------------------------#
if [ $choice = 5 ]
then
	reset
fi
