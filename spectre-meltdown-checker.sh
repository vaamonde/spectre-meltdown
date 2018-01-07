#! /bin/sh
# Spectre & Meltdown checker
# Stephane Lesimple
# Modificado por: Robson Vaamonde
# Traduzido por: Robson Vaamonde
# Procedimentos em TI e Bora para Prática!!!

VERSION=0.07
SUB_VERSION=1.0
DATA=`date +%d/%m/%Y-%H:%M`

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

# ----------------------------------------------------------------------
# extract-vmlinux - Extract uncompressed vmlinux from a kernel image
#
# Inspired from extract-ikconfig
# (c) 2009,2010 Dick Streefland <dick@streefland.net>
#
# (c) 2011      Corentin Chary <corentin.chary@gmail.com>
#
# Licensed under the GNU General Public License, version 2 (GPLv2).
# ----------------------------------------------------------------------

check_vmlinux()
{
	file "$1" 2>/dev/null | grep -q ELF || return 1
	return 0
}

try_decompress()
{
        # The obscure use of the "tr" filter is to work around older versions of
        # "grep" that report the byte offset of the line instead of the pattern.

        # Try to find the header ($1) and decompress from here
        for     pos in `tr "$1\n$2" "\n$2=" < "$img" | grep -abo "^$2"`
        do
                pos=${pos%%:*}
                tail -c+$pos "$img" | $3 > $vmlinuxtmp 2> /dev/null
                check_vmlinux $vmlinuxtmp && echo $vmlinuxtmp || rm -f $vmlinuxtmp
        done
}

extract_vmlinux()
{
	img="$1"

	# Prepare temp files:
	vmlinuxtmp=$(mktemp /tmp/vmlinux-XXX)

	# Initial attempt for uncompressed images or objects:
	check_vmlinux $img

	# That didn't work, so retry after decompression.
	try_decompress '\037\213\010' xy    gunzip     || \
	try_decompress '\3757zXZ\000' abcde unxz       || \
	try_decompress 'BZh'          xy    bunzip2    || \
	try_decompress '\135\0\0\0'   xxx   unlzma     || \
	try_decompress '\211\114\132' xy    'lzop -d'
}


/bin/echo "Ferramenta de detecção de mitigação Specter e Meltdown v$VERSION - sv$SUB_VERSION"
/bin/echo "Data e hora da verificação: $DATA"
/bin/echo "Script original criado por: Stephane Lesimple - v$VERSION"
/bin/echo "Script modificado/traduzido por: Robson Vaamonde - sv$SUB_VERSION"
/bin/echo "Site: procedimentosemti.com.br | boraparapratica.com.br"
/bin/echo

# SPECTRE 1
/bin/echo -e "\033[1;34mCVE-2017-5753 [Controle de verificação de limites] aka 'Variação 1 do Spectre'\033[0m"
/bin/echo -n "* Kernel compilado com o Opcode LFENCE inserido nos locais apropriados: "

status=0
img=''
[ -e /boot/vmlinuz-$(uname -r) ] && img=/boot/vmlinuz-$(uname -r)
[ -e /boot/vmlinux-$(uname -r) ] && img=/boot/vmlinux-$(uname -r)
[ -e /boot/bzImage-$(uname -r) ] && img=/boot/bzImage-$(uname -r)
if [ -z "$img" ]; then
	pstatus yellow DESCONHECIDO "não conseguir encontrar a imagem do kernel em / boot"
else
	vmlinux=$(extract_vmlinux $img)
	if [ -z "$vmlinux" -o ! -r "$vmlinux" ]; then
		pstatus yellow DESCONHECIDO "não conseguir extrair seu kernel"
	elif ! which objdump >/dev/null 2>&1; then
		pstatus yellow DESCONHECIDO "faltando a ferramenta 'objdump', instale-a, geralmente está no pacote binutils"
	else
		nb_lfence=$(objdump -D "$vmlinux" | grep -wc lfence)
		if [ "$nb_lfence" -lt 60 ]; then
			pstatus red NÃO "só $nb_lfence opcodes encontrados, devem ser >= 60"
			status=1
		else
			pstatus green SIM "$nb_lfence opcodes encontrado, que é >= 60"
			status=2
		fi
		rm -f $vmlinux
	fi
fi

/bin/echo -ne "> \033[46m\033[30mSTATUS:\033[0m "
[ "$status" = 0 ] && pstatus yellow DESCONHECIDO
[ "$status" = 1 ] && pstatus red VULNERÁVEL
[ "$status" = 2 ] && pstatus green 'NÃO VULNERÁVEL'


# VARIANT 2
/bin/echo
/bin/echo -e "\033[1;34mCVE-2017-5715 [injecção de alvo de ramo] aka 'Variação 2 do Spectre'\033[0m"
/bin/echo "* Mitigação 1"
/bin/echo -n "*   Hardware (CPU microcode) suporte à mitigação: "
if [ ! -e /dev/cpu/0/msr ]; then
	modprobe msr 2>/dev/null && insmod_msr=1
fi
if [ ! -e /dev/cpu/0/msr ]; then
	pstatus yellow DESCONHECIDO "não conseguir ler /dev/cpu/0/msr, o suporte ao msr está ativado em seu kernel?"
else
	# same that rdmsr 0x48 but without needing the rdmsr tool
	dd if=/dev/cpu/0/msr of=/dev/null bs=8 count=1 skip=9 2>/dev/null
	if [ $? -eq 0 ]; then
		pstatus green SIM
	else
		pstatus red NÃO
	fi
fi

if [ "$insmod_msr" = 1 ]; then
	rmmod msr 2>/dev/null
fi

/bin/echo -n "*   Suporte de Kernel para IBRS: "
if [ -e /sys/kernel/debug/sched_features ]; then
	mount -t debugfs debugfs /sys/kernel/debug 2>/dev/null && mounted_debugfs=1
fi
if [ -e /sys/kernel/debug/ibrs_enabled ]; then
	pstatus green SIM
	ibrs_supported=1
else
	pstatus red NÃO
fi

ibrs_enabled=$(cat /sys/kernel/debug/ibrs_enabled 2>/dev/null)
/bin/echo -n "*   IBRS habilitado para o espaço do Kernel: "
case "$ibrs_enabled" in
	"") [ "$ibrs_supported" = 1 ] && pstatus yellow DESCONHECIDO || pstatus red NÃO;;
	0)     pstatus red NÃO;;
	1 | 2) pstatus green SIM;;
	*)     pstatus yellow DESCONHECIDO;;
esac

/bin/echo -n "*   IBRS habilitado para o espaço do usuário: "
case "$ibrs_enabled" in
	"") [ "$ibrs_supported" = 1 ] && pstatus yellow DESCONHECIDO || pstatus red NÃO;;
	0 | 1) pstatus red NÃO;;
	2) pstatus green SIM;;
	*) pstatus yellow DESCONHECIDO;;
esac

if [ "$mounted_debugfs" = 1 ]; then
	umount /sys/kernel/debug
fi

/bin/echo "* Mitigação 2"
/bin/echo -n "*   Kernel compilado com retpolines: "
# XXX this doesn't mean the kernel has been compiled with a retpoline-aware gcc
if [ -e /proc/config.gz ]; then
	if zgrep -q '^CONFIG_RETPOLINE=y' /proc/config.gz; then
		pstatus green SIM
		retpoline=1
	else
		pstatus red NÃO
	fi
elif [ -e /boot/config-$(uname -r) ]; then
	if grep  -q '^CONFIG_RETPOLINE=y' /boot/config-$(uname -r); then
		pstatus green SIM
		retpoline=1
	else
		pstatus red NÃO
	fi
else
	pstatus yellow DESCONHECIDO "não conseguiu ler a configuração do kernel"
fi

/bin/echo -ne "> \033[46m\033[30mSTATUS:\033[0m "
if grep -q AMD /proc/cpuinfo; then
	pstatus green "NÃO VULNERÁVEL" "sua CPU não é vulnerável conforme o fornecedor"
elif [ "$ibrs_enabled" = 1 -o "$ibrs_enabled" = 2 ]; then
	pstatus green "NÃO VULNERÁVEL" "IBRS mitiga a vulnerabilidade"
elif [ "$retpoline" = 1 ]; then
	pstatus green "NÃO VULNERÁVEL" "retpolines mitigar a vulnerabilidade"
else
	pstatus red VULNERÁVEL "Hardware IBRS + suporte kernel OU kernel com retpolines são necessários para mitigar a vulnerabilidade"
fi

# MELTDOWN
/bin/echo
/bin/echo -e "\033[1;34mCVE-2017-5754 [carga de cache de dados desonesto] aka 'Meltdown' aka 'Variação 3'\033[0m"
/bin/echo -n "* O kernel suporta o isolamento da tabela de páginas (PTI): "
if [ -e /proc/config.gz ]; then
	if zgrep -q '^CONFIG_PAGE_TABLE_ISOLATION=y' /proc/config.gz; then
		pstatus green SIM
		kpti_support=1
	else
		pstatus red NÃO
	fi
elif [ -e /boot/config-$(uname -r) ]; then
	if grep  -q '^CONFIG_PAGE_TABLE_ISOLATION=y' /boot/config-$(uname -r); then
		pstatus green SIM
		kpti_support=1
	else
		pstatus red NÃO
	fi
elif [ -e /boot/System.map-$(uname -r) ]; then
	if grep -qw kpti_force_enabled /boot/System.map-$(uname -r); then
		pstatus green SIM
		kpti_support=1
	else
		pstatus red NÃO
	fi
else
	pstatus yellow DESCONHECIDO "não conseguir ler a configuração do kernel"
fi

/bin/echo -n "* PTI ativado e ativo: "
if grep ^flags /proc/cpuinfo | grep -qw pti; then
	pstatus green SIM
	kpti_enabled=1
elif dmesg | grep -q 'Isolamento de tabelas de páginas Kernel / User: habilitado'; then
	pstatus green SIM
	kpti_enabled=1
else
	pstatus red NÃO
fi

/bin/echo -ne "> \033[46m\033[30mSTATUS:\033[0m "
if grep -q AMD /proc/cpuinfo; then
	pstatus green "NÃO VULNERÁVEL" "sua CPU não é vulnerável conforme o fornecedor"
elif [ "$kpti_enabled" = 1 ]; then
	pstatus green "NÃO VULNERÁVEL" "PTI atenua a vulnerabilidadey"
else
	pstatus red "VULNERÁVEL" "PTI é necessário para mitigar a vulnerabilidade"
fi


/bin/echo
if [ "$USER" != root ]; then
	/bin/echo "Observe que você deve iniciar esse script com privilégios de root para obter informações precisas"
	/bin/echo "Você pode tentar o seguinte comando: sudo $0"
fi

