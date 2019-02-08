#!/bin/bash -e
clear
echo "============================================"
echo "Instalador de MariaDB"
echo "============================================"
banner(){
  echo "+------------------------------------------+"
  printf "| %-40s |\n" "`date`"
  echo "|                                          |"
  printf "|`tput bold` %-40s `tput sgr0`|\n" "$@"
  echo "+------------------------------------------+"
}
banner "Criado por Tiago Mendes"
sleep 3
version=$(lsb_release -a 2>/dev/null | grep Description | awk '{print $2}' | awk -F\. '{print$1}')
install_repo(){
FILE="/etc/yum.repos.d/mariadb.repo"
if [ $version == "RedHat" ]; then
echo "Adicionando repositorio mariadb aos repositorios locais do $version"
/usr/bin/cat <<EOT >>$FILE
MariaDB 10.3 RedHat repository list - created 2018-12-13 18:13 UTC
http://downloads.mariadb.org/mariadb/repositories/
[mariadb]
name = MariaDB
baseurl=http://yum.mariadb.org/10.3/rhel7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOT
fi
if [ $version == "Fedora" ]; then
echo "Adicionando repositorio mariadb aos repositorios locais do $version"
/usr/bin/cat <<EOT >>$FILE
MariaDB 10.3 Fedora repository list - created 2019-02-06 11:24 UTC
http://downloads.mariadb.org/mariadb/repositories/
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.3/fedora28-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOT
fi
echo "Precione qualquer tecla para sair..."
read -s exit
exit 1
}
instalar_packages(){
	for i in "mariadb httpd"
		do 
		echo $i
		echo "Que pacote deseja instalar: $i"
		read -e package
		if [ $version == "Fedora" ]; then
		dnf install -y -v $package
		fi
		if [ $version == "Fedora" ]; then
                yum install -y -v $package
                fi
		echo "================================================"
		echo "Instalação concluida, vamos levantar os serviços"
		echo "================================================"
		systemctl start $package.service
		systemctl enable $package.service
		done 
}
mariadb(){
echo "========================================================="
echo "Vamos criar a base de dados com os pivilégios necessários"
echo "========================================================="
/usr/bin/mysql_secure_installation
echo "===================================================="
echo "Verificar se a base de dados já existe ou se é nova"
echo "===================================================="
echo "Hostname da maquina da base de dados: "
read -e dbhost
echo "Nome da Base de dados: "
read -e dbname
echo "User da Base de dados: "
read -e dbuser
while true; do
    read -s -p "Senha de acesso a Base de dados para o user root: " dbpass  
    echo "$dbpass" | sed 's/./*/g'
    read -s -p "Repita a senha: " dbpass2
    echo "$password2" | sed 's/./*/g'
    [ "$dbpass" = "$dbpass2" ] && echo "Password Identicas" && break
    echo "Passwords nao combinam,tentar novamente"
done
echo "======================================================"
echo "Criando e Verificando a existencia da base de dados"
echo "======================================================"
mysql=`mysql --host=$dbhost --user=root --password=$dbpass -s -N --execute="SELECT IF(EXISTS (SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = '$dbname'), 'Yes','No')";`
if [ "$mysql" == "Yes" ]; then
        echo "Base de dados existente, deseja usar a mesma? (y/n)"
        read -e usethis
        if [ "$usethis" == n ]; then
                echo "Voltar a correr o script para gerar nova base de dados"
                echo "Precione qualquer tecla para sair..."
                read -s exit
                exit 1
	else
	echo "====================================================================="
        echo "Voltar a correr o script para instalacao do wordpress na bd existente"
        echo "====================================================================="

        fi

else
        mysql=`mysql --host=$dbhost --user=root --password=$dbpass --execute="CREATE DATABASE $dbname";`
	mysql=`mysql --host=$dbhost --user=root --password=$dbpass --execute="CREATE USER '$dbuser'@'$dbhost' IDENTIFIED BY '$dbpass'";`
	echo "entrei"
	mysql=`mysql --host=$dbhost --user=root --password=$dbpass --execute="GRANT ALL PRIVILEGES on $dbname.* to '$dbuser'@'$dbhost' identified by '$dbpass'";`
        echo "=============================================="
        echo "Base de dados criada e privilegios concedidos!"
        echo "=============================================="
fi
}
remove_mariadb(){
echo "===================================================="
echo "Desinstalando MariaDB, aguarde..."
echo "===================================================="
sudo yum remove mariadb mariadb-server -y
echo "---- A remover directoria do mysql----"
rm -rf /var/lib/mysql
}
wordpress(){
echo "================================================"
echo "O script vai proceder a instalacao do wordpress!"
echo "================================================"
echo "Começar a instalação? (y/n)"
read -e run
if [ "$run" == n ] ; then
exit
else
echo "===================================================="
echo "O script está instalar o Wordpress, aguarde..."
echo "===================================================="
#Faz o download dos binarios
wget -O wordpress-latest.tar.gz https://wordpress.org/latest.tar.gz
#unzip
tar -zxvf wordpress-latest.tar.gz
/usr/bin/cp -avr wordpress/* /var/www/html/
/usr/sbin/restorecon -r /var/www/html
/usr/bin/mkdir /var/www/html/wp-content/uploads
/usr/bin/chown -R apache:apache /var/www/html/
/usr/bin/chmod -R 755 /var/www/html/
cd /var/www/html/
#cria o wp config
/usr/bin/cp wp-config-sample.php wp-config.php
echo "Nome da Base de dados: "
read -e dbname
echo "User da Base de dados: "
read -e dbuser
while true; do
    read -s -p "Senha de acesso a Base de dados para o user root: " dbpass
    echo "$dbpass" | sed 's/./*/g'
    read -s -p "Repita a senha: " dbpass2
    echo "$password2" | sed 's/./*/g'
    [ "$dbpass" = "$dbpass2" ] && echo "Password Identicas" && break
    echo "Passwords nao combinam,tentar novamente"
done
#sobreescreve as configs do Base de dados usando python
perl -pi -e "s/database_name_here/$dbname/g" wp-config.php
perl -pi -e "s/username_here/$dbuser/g" wp-config.php
perl -pi -e "s/password_here/$dbpass/g" wp-config.php

## caso a maquina nao tenha python uncomment estas linhas##########
#sed -i "/DB_NAME/s/'[^']*'/'$dbname'/2" wp-config.php
#sed -i "/DB_USER/s/'[^']*'/'$dbuser'/2" wp-config.php
#sed -i "/DB_PASSWORD/s/'[^']*'/'$dbpass'/2" wp-config.php
###################################################################
#define WP salts-necessario
perl -i -pe'
  BEGIN {
    @chars = ("a" .. "z", "A" .. "Z", 0 .. 9);
    push @chars, split //, "!@#$%^&*()-_ []{}<>~\`+=,.;:/?|";
    sub salt { join "", map $chars[ rand @chars ], 1 .. 64 }
  }
  s/chagasfe/salt()/ge
' wp-config.php
echo "========================="
echo "Instalação completa!"
echo "========================="
fi
}
remove_wordpress(){
echo "=========================================="
echo " A remover diretorio wordpress do apache"
echo "=========================================="
rm -rf /var/www/html/*  
echo "=========================================="
echo " A remover base de dados wordpress"
echo "=========================================="
echo "Nome da Base de dados: "
read -e dbname
echo "User da Base de dados: "
read -e dbuser
read -s -p "Senha de acesso a Base de dados: " dbpass
mysql=`mysql --host=$dbhost --user=$dbuser --password=$dbpass $dbname --execute="DROP DATABASE $dbname";`

}
firewall(){
echo "================================"
echo "Aplicando regras de firewall...!"
echo "================================"
sudo firewall-cmd --permanent --zone=public --add-service=http
sudo firewall-cmd --permanent --zone=public --add-service=https
sudo firewall-cmd --reload
exit
}
options=("Adicionar Repositorio" "Instalar Packages" "Configuracao MariaDB" "Remove MariaDB" "Install Wordpress" "Remove Wordpress" "Firewall configuration" "Quit")
select opt in "${options[@]}"
do    
	case $opt in
        "Adicionar Repositorio")
        install_repo
        break
	    ;;
        "Instalar Packages")
        instalar_packages
        sudo yum clean all
	break
            ;;
	"Configuracao MariaDB")
        mariadb
        break
            ;;
        "Remove MariaDB")
        remove_mariadb
        break
            ;;
	"Install Wordpress")
        wordpress
        break
	    ;;
	"Firewall Configuration")
       	firewall 
        break
            ;;
	"Remove Wordpress")
        remove_wordpress
        break
            ;;
        "Quit")
         exit 0
            break
            ;;
        *) echo "Opcao invalida $REPLY";;
    esac
done 
