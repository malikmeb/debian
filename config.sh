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
	echo 'var_username ALL=(ALL:ALL) ALL' >> /etc/sudoers
	sed -i -e "s/var_username/$username/g" /etc/sudoers
	echo " "
	echo "*********************************************"
	echo "*************** SUDO CONFIGURÉ ***************"
	echo "*********************************************"
	Menu
	read -p "Saisir votre choix :" choice
}
Cartes()
{
	ip a 
	echo '*****insérer la carte a configuré:*****'
	read -p "Saisir votre choix :" carte1
	echo " " >> /etc/network/interfaces
	echo auto $carte1 >> /etc/network/interfaces
	echo '*****static ou dhcp?*****'
	read -p "Saisir votre choix :" type 
if [ $type = "static" ]
then
	echo iface $carte1 inet $type  >> /etc/network/interfaces
elif [ $type = "dhcp" ]
then
	echo iface $carte1 inet $type  >> /etc/network/interfaces
fi
	echo "*****Adresse IP de la machine? (indiquez le CIDR)*****"
	read -p "Saisir votre choix :" ip_adress
	echo address $ip_adress >> /etc/network/interfaces
	systemctl restart networking.service
	echo "***** Indiquez la carte connectée en NAT *****"
	ip a
	read -p "Saisir votre choix :" nat_card
	sudo ifup $nat_card
	dhclient -r

	echo " "
	echo "*********************************************"
	echo "*************** CARTE CONFIGURÉE ***************"
	echo "*********************************************" 

echo "*****Voulez-vous configurer une autre carte?(y/n)*****"
read choice2

if [ $choice2 = "y" ]
then
	Cartes
elif [ $choice2 = "n" ]
then
	Menu
	read -p "Saisir votre choix :" choice
fi
}


dhcp()
{
	apt-get -y install isc-dhcp-server
	rm /etc/dhcp/dhcpd.conf
	touch /etc/dhcp/dhcpd.conf
	echo "*****indiquez le sous-réseau:*****"
	read -p "Saisir votre choix :" subnet
	echo "*****indiquez le masque de sous-réseau:*****"
	read -p "Saisir votre choix :" net_mask
	echo "*****Indiquez le start range:*****"
	read -p "Saisir votre choix :" range_start
	echo "*****Indiquez le end range:*****"
	read -p "Saisir votre choix :" range_end
	echo "*****Indiquez l'adresse DNS*****"
	read -p "Saisir votre choix :" dns_ip
	echo "*****Indiquez l'adresse du routeur:*****"
	read -p "Saisir votre choix :" outer_ip

	echo 'default-lease-time 86400; max-lease-time 172800;' >> /etc/dhcp/dhcpd.conf
	echo 'subnet var_subnet netmask var_netmask { range var_range_start var_range_end; option domain-name-servers var_dns_ip; option routers var_router_ip; }' >> /etc/dhcp/dhcpd.conf
	sed -i -e "s/var_subnet/$subnet/g" -e "s/var_netmask/$net_mask/g" /etc/dhcp/dhcpd.conf
	sed -i -e "s/var_range_start/$range_start/g" -e "s/var_range_end/$range_end/g" /etc/dhcp/dhcpd.conf
	sed -i -e "s/var_dns_ip/$dns_ip/g" -e "s/var_router_ip/$router_ip/g" /etc/dhcp/dhcpd.conf


	echo "*****Sur quelle carte Voulez-vous que le dhcp soit connecté?*****"
	echo " "
	ip a | grep ens

	read dhcp_listen


	sed -i -e '/INTERFACESv4/d' /etc/default/isc-dhcp-server
	echo 'INTERFACESv4="CARTE_V4"' >> /etc/default/isc-dhcp-server
	#echo INTERFACESv4=\"\$dhcp_listen\"\ >> /etc/default/isc-dhcp-server
	sed -i -e "s/CARTE_V4/$dhcp_listen/g" /etc/default/isc-dhcp-server
	systemctl restart isc-dhcp-server

	echo "*********************************************"
	echo "*************** DHCP CONFIGURÉ ***************"
	echo "*********************************************"

	Menu
	read -p "Saisir votre choix :" choice

}

dns()
{
	apt-get install -y bind9 bind9utils
	echo "*****Nom de domaine?:*****"
	read -p "Saisir votre choix :" dns_name
	echo 'zone var_dns_name { type master; file "/etc/bind/db.var_dns_name"; };' >> /etc/bind/named.conf.local
	sed -i -e "s/var_dns_name/$dns_name/g" /etc/bind/named.conf.local
	cp /etc/bind/db.empty /etc/bind/db.$dns_name
	sed -i -e "s/root.localhost./root.$dns_name./g" /etc/bind/db.$dns_name
	sed -i -e "s/localhost./ns.$dns_name./g" /etc/bind/db.$dns_name
	sed -i '$d' /etc/bind/db.$dns_name

	echo 'var_dns_name.  IN  NS  ns.var_dns_name.' >> /etc/bind/db.$dns_name
	sed -i -e "s/var_dns_name/$dns_name/g" /etc/bind/db.$dns_name
	echo "*****Adresse IP du DNS hôte?:*****"
	read -p "Saisir votre choix :" dns_ip_hote
	echo "ns   IN      A      $dns_ip_hote" >> /etc/bind/db.$dns_name
	echo 'options { directory "/var/cache/bind";' > /etc/bind/named.conf.options
	echo ' ' >> /etc/bind/named.conf.options
	echo 'allow-recursion { any; }; forwarders { 8.8.8.8; }; dnssec-enable no; dnssec-validation no; auth-nxdomain no; listen-on-v6 { any; }; listen-on { any; }; allow-query { any; }; };' >> /etc/bind/named.conf.options
	sudo named-checkconf
	sudo named-checkzone $dns_name /etc/bind/db.$dns_name
	systemctl restart bind9

	echo "*********************************************"
	echo "*************** DNS CONFIGURÉ ***************"
	echo "*********************************************"

	Menu 
	read -p "Saisir votre choix :" choice

}

enregistrement()
{
	echo "***** Nom de domaine?:*****"
	read -p "Saisir votre choix :" dns_name
	echo "*****FQDN?:*****"
	read -p "Saisir votre choix :" fqdn
	echo "*****Type d'enregistrement (A/CNAME/MX/TXT)*****"
	read -p "Saisir votre choix :" type_enregistrement
	echo "*****Adresse IP*****"
	read -p "Saisir votre choix :" ip_enregistrement

	echo 'var_fqdn	 IN 	var_type_enregistrement 	var_ip_enregistrement' >> /etc/bind/db.$dns_name
	sed -i -e "s/var_fqdn/$fqdn/g" -i -e "s/var_type_enregistrement/$type_enregistrement/g" -i -e "s/var_ip_enregistrement/$ip_enregistrement/g" /etc/bind/db.$dns_name
	echo " "
	echo "*********************************************"
	echo "********enregistrement enregistré************"
	echo "*********************************************"
	echo " "
	echo "*****Voulez-vous ajouter un autre enregistrement? (y/n) *****"
	read -p "Saisir votre choix :" retry_enregistrement
	if [ retry_enregistrement = 'y' ]
	then
		enregistrement
	elif [ retry_enregistrement = 'n' ]
	then 
		Menu
		read -p "Saisir votre choix :" choice
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
		echo "***** Nom de domaine?:*****"
		read -p "Saisir votre choix :" dns_name
		echo "***** Indiquez l'adresse IP *****"
		read -p "Saisir votre choix :" sup_ip
		sed -i "/$sup_ip/d" /etc/bind/db.$dns_name
		echo "***** DONE *****"
		Menu
		read -p "Saisir votre choix :" choice
	elif [ $choice_sup = 2 ]
	then
		echo "***** Nom de domaine?:*****"
		read -p "Saisir votre choix :" dns_name
		echo "***** Indiquez le FQDN *****"
		read -p "Saisir votre choix :" sup_fqdn
		sed -i "/$sup_fqdn/d" /etc/bind/db.$dns_name
		echo "***** DONE *****"
		Menu
		read -p "Saisir votre choix :" choice
	elif [ $choice_sup = 3 ]
	then
		echo "***** Nom de domaine?:*****"
		read -p "Saisir votre choix :" dns_name
		echo "***** Indiquez le type d'enregistrement *****"
		read -p "Saisir votre choix :" sup_enregistrement
		sed -i "/$sup_enregistrement/d" /etc/bind/db.$dns_name
		echo "***** DONE *****"
		Menu
		read -p "Saisir votre choix :" choice
	elif [ $choice_sup = 4 ]
	then
		Menu 
		read -p "Saisir votre choix :" choice
	fi
}

reset()
{
	echo "********1. BACK-UP DHCP*************"
	echo "********2. BACK-UP DNS**************"

	read -p "Saisir votre choix :" choice_reset

	if [ $choice_reset = 1 ]
	then
		apt-get remove --purge -y isc-dhcp-server

	elif [ $choice_reset = 2 ]
	then
		apt-get remove --purge -y bind9
	fi

	Menu
	read -p "Saisir votre choix :" choice
}






Menu
read -p "Saisir votre choix :" choice
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
