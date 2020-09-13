
#!/bin/bash
Menu()
{
echo "---------------------------------------------"
echo "1. Ajouter un utilisateur en tant que sudoer"
echo "2. Configurer les cartes virtuelles"
echo "3. Installer un service DHCP"
echo "4. Installer un service DNS"
echo "5. BACK-UP (reset)"
echo "---------------------------------------------"
}

sudoer()
{
	echo 'Utilisateur à mettre en sudo:'
	read username
	sudo usermod -aG sudo $username
	Menu
	read choice
}
Cartes()
{
	ip a | grep ens 
	echo 'insérer la carte a configuré:'
	read carte1
	echo auto $carte1 >> /etc/network/interfaces
	echo 'static ou dhcp?'
	read type 
if [ $type = "static" ]
then
	echo iface $carte1 inet $type  >> /etc/network/interfaces
elif [ $type = "dhcp" ]
then
	echo iface $carte1 inet $type  >> /etc/network/interfaces
fi
	echo "Adresse IP de la machine? (indiquez le CIDR)"
	read ip_adress
	echo address $ip_adress >> /etc/network/interfaces
	systemctl restart networking.service

echo "Voulez-vous configurer une autre carte?(y/n)"
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
	echo "indiquez le sous-réseau:"
	read subnet
	echo "indiquez le masque de sous-réseau:"
	read net_mask
	echo "Indiquez le start range:"
	read range_start
	echo "Indiquez le end range:"
	read range_end
	echo "Indiquez l'adresse DNS"
	read dns_ip
	echo "Indiquez l'adresse du routeur:"
	read router_ip


	sed -i -e "s/ip_address/$subnet/g" -e "s/net_mask/$net_mask/g" dhcpd.conf
	sed -i -e "s/range_start/$range_start/g" -e "s/range_end/$range_end/g" dhcpd.conf
	sed -i -e "s/dns_ip/$dns_ip/g" -e "s/router_ip/$router_ip/g" dhcpd.conf

	mv dhcpd.conf /etc/dhcp/

	echo "Sur quelle carte Voulez-vous que le dhcp soit connecté?"
	echo " "
	ip a | grep ens

	read dhcp_listen

	sed -i -e 's/4=""/"$dhcp_listen"/g' /etc/default/isc-dhcp-server

	systemctl restart isc-dhcp-server


	Menu
	read choice

}

reset()
{
	apt-get remove --purge -y isc-dhcp-server
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
#------------------BACK-UP-----------------------------#
if [ $choice = 5 ]
then
	reset
fi
