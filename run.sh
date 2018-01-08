#! /bin/sh
# Script de verificação da vulnerabilidade Spectre & Meltdown nos processadores Intel
# Script compilado em C utilizado o shc: https://github.com/neurobin/shc
# Criado por: Pavel Boldin
# Modificado por: Robson Vaamonde
# Traduzido por: Robson Vaamonde
# Site: www.procedimentosemti.com.br
# Facebook: facebook.com/ProcedimentosEmTI
# Facebook: facebook.com/BoraParaPratica
# YouTube: youtube.com/BoraParaPratica
# Data de atualização: 07/01/2018

VERSION=1.0
DATA=`date +%d/%m/%Y-%H:%M`
KERNEL=`uname -r`
LINUX=`hostnamectl | tail -n3 | head -n1 | cut -d':' -f2`

pstatus()
{
	case "$1" in
		red)    col="\033[101m\033[30m";;
		green)  col="\033[102m\033[30m";;
		yellow) col="\033[103m\033[30m";;
		*)      col="";;
	esac
	/bin/echo -ne "$col $2 \033[0m"
	[ -n "$3" ] && /bin/echo -n " ($3)"
	/bin/echo
}

/bin/echo "Ferramenta de detecção de mitigação Specter e Meltdown v$VERSION"
/bin/echo "Data e hora da verificação: $DATA"
/bin/echo "Script original criado por: Pavel Boldin"
/bin/echo "Script modificado/traduzido por: Robson Vaamonde"
/bin/echo "Site: procedimentosemti.com.br | boraparapratica.com.br"
/bin/echo

# Versão do seu Kernel e do GNU/Linux
/bin/echo -e "\033[1;34mVersão do Kernel instalada e rodando no seu GNU/Linux\033[0m"
/bin/echo -e "* Versão do Kernel instalada: $KERNEL"
/bin/echo -e "* Versão do GNU/Linux instalada:$LINUX"
pstatus red 'POSSIBILIDADE DE ESTÁ VUNERAVLEL'
/bin/echo

find_linux_proc_banner() {
	$2 sed -n -E 's/^(f[0-9a-f]+) .* linux_proc_banner$/\1/p' $1
}

echo "Procurando linux_proc_banner em /proc/kallsyms"
linux_proc_banner=$(find_linux_proc_banner /proc/kallsyms)
if test -z $linux_proc_banner; then
	echo "Arquivo protegido, por-favor rodar o comando como root: ./sudo $0"
	set -x
	linux_proc_banner=$(\
		find_linux_proc_banner /proc/kallsyms sudo)

	set +x
fi
if test -z $linux_proc_banner; then
	echo "Arquivo não encontrado, lendo o arquivo: /boot/System.map-$(uname -r)"
	set -x
	linux_proc_banner=$(\
		find_linux_proc_banner /boot/System.map-$(uname -r) sudo)
	set +x
fi
if test -z $linux_proc_banner; then
	echo "Arquivo não encontrado, lendo o arquivo /boot/System.map"
	set -x
	linux_proc_banner=$(\
		find_linux_proc_banner /boot/System.map sudo)
	set +x
fi
if test -z $linux_proc_banner; then
	echo "Arquivo não encontrado: linux_proc_banner, incapaz de testar a vulnerabilidade"
	exit 0
fi

./meltdown $linux_proc_banner 10
vuln=$?

if test $vuln -eq 132; then
	echo "INSTRUÇÃO ILEGAL"
	echo "Tente recompilar com a opção:"
	echo " make CFLAGS='-DHAVE_RDTSCP=0' clean all"
	echo "Executar novamente o script"
fi
if test $vuln -eq 1; then
	echo "POR FAVOR, VERIFIQUE AS INFORMAÇÕES NESSA URL: https://github.com/paboldin/meltdown-exploit/issues/19"
	echo "VULNERÁVEL"
	uname -rvi
	head /proc/cpuinfo
	exit 1
fi
if test $vuln -eq 0; then
	echo "POR FAVOR, VERIFIQUE AS INFORMAÇÕES NESSA URL: https://github.com/paboldin/meltdown-exploit/issues/22"
	echo "NÃO VULNERÁVEL"
	uname -rvi
	head /proc/cpuinfo
	exit 0
fi
