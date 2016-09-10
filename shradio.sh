#!/bin/bash

#------------------------------------------------------------------------------#
# Data: 15 de Agosto de 2016
# Criado por: Juliano Santos [x_SHAMAN_x]
# Script: shRadio2.sh
# Descrição: Script para execução de radios online atraves do serviço de stream
#------------------------------------------------------------------------------#

# Verifica pacotes necessários
if [ ! -x "$(which mplayer)" ]; then
    echo "$(basename "$0"): Erro: 'mplayer' não está instalado."; exit 1
elif [ ! -x "$(which yad)" ]; then
    echo "$(basename "$0"): Erro: 'yad' não está instalado."; exit 1
elif [ ! -x "$(which curl)" ]; then
    echo "$(basename "$0"): Erro: 'curl' não está instalado."; exit 1
fi

# Suprimir erros
exec 2>/dev/null

# script
SCRIPT="$(basename "$0")"

# CONF
TMP_LISTEN=$(mktemp --tmpdir=/tmp shradio.XXXXXXXXXX)
SITE=https://www.internet-radio.com
GENRE_LIST=/tmp/genres.list

#Icone
ICON_APP=/usr/share/icons/HighContrast/48x48/emblems/emblem-music.png

# Cria uma trap, se o script for interrompido pelo usuário
trap '_exit' TERM INT

# Encerra script
function _exit()
{
	# Apaga arquivo temporário
	rm -f $TMP_LISTEN
	# Mata os subshell's e shell principal
	kill -9 $(pidof mplayer yad) \
			$(ps aux | grep -v grep | grep "$SCRIPT" | grep -v "$$" | awk '{print $2}') &>/dev/null

	exit 0
}

function PlayRadio()
{
    local listen=$(echo "$*" | cut -d"|" -f3)   # Serviço de stream
    local genre=$(echo "$*" | cut -d"|" -f2)    # Gênero
    local radio=$(echo "$*" | cut -d"|" -f1)    # Nome da Radio
	
	# Se rádio for selecionada finaliza o processo 'mplayer'
    if [ "$listen" ]; then
		kill -9 $(pidof mplayer); else return 0; fi

    # Executa o LISTEN da rádio em segundo plano e redireciona as informações para o arquivo 'TMP_LISTEN'
    mplayer "$listen" &>$TMP_LISTEN &
    # Variáveis locais.
    local Music RadioName Swap
    # Status de seleção da rádio pelo usuário
    local ini=0
    # Aguarda conexão com o servidor de stream
    for cont in $(seq 4); do
        echo; sleep 1; done | yad --progress \
                                  --fixed \
                                  --center \
                                  --no-buttons \
                                  --title "$radio" \
                                  --progress-text="Conectando '$listen'..." \
                                  --auto-close --pulsate

# Atualiza a cada '3' segundos as informações da rádio e armazena as informações em
    # 'Music' e 'RadioName'.
    while true
    do
        # Sincroniza informações da 'rádio'
        Music="$(cat $TMP_LISTEN | grep -i "StreamTitle" | awk 'END {print}' | cut -d'=' -f2- | cut -d';' -f1 | tr -d "['\"]")"
        RadioName="$(cat $TMP_LISTEN | egrep -i "^Name" | awk 'END {print}' | cut -d':' -f2-)"

        # Se a música mudou ou se a rádio foi selecionada pelo usuário, envia uma notificação
        # com as informações da nova faixa.
        if [ "$Music" != "$Swap" -o $ini -eq 0 ]; then
            Swap="$Music"                           # Música atual.
            Music="${Music:-Desconhecido}"          # 'Desconhecido' Valor padrão
            RadioName="${RadioName:-Desconhecido}"

            # Envia notificação
            notify-send --app-name="shRadio" --icon=$ICON_APP "$Music" "$RadioName"
            ini=1   # status
        fi
        sleep 3  # N> low cpu 
    done
}

# Janela principal
function main()
{
	###### JANELA PRINCIPAL ######
	COUNT=$(yad --form \
		--center \
		--width 300 \
		--height 300 \
		--fixed \
		--title "[x_SHAMAN_x] - $SCRIPT" \
		--image $ICON_APP \
		--text "Seja bem vindo ao '<b>$SCRIPT</b>' !!!!\nSeu script de Rádio online.\nVocẽ irá encontrar os mais diversos gêneros musicais.\nA lista de rádios são obtidas apartir da fonte\n'<b>$SITE</b>'.\nPara começar, escolha o seu gẽnero músical, clicando\nno botão '<b>Gêneros</b>'\nObs: Todas as informações contidas na lista, são\nsincronizadas com a fonte." \
		--field '':LBL '' \
		--field "Defina o número de paginas a serem pesquisadas,\naumentando assim a quantidade de rádios encontradas.\n\nObs: Dependendo do valor, a busca poderá\ndemorar um pouco. <b>:)</b>":LBL '' \
		--field 'Num. paginas.':NUM '1!1..20!1' \
		--button 'Gêneros!gtk-cdrom':0 \
		--button 'Limpar cache!gtk-delete':1 \
		--button 'Sair!gtk-quit':252)

	# Retorno
	RETVAL=$?

	# Se a janela for fechada	
	if [ $RETVAL -eq 252 ]; then
		 _exit
	# Limpar cache
	elif [ $RETVAL -eq 1 ]; then
		yad --form \
			--image=gtk-dialog-question \
			--center \
			--fixed \
			--title "Limpar cache" \
			--text "Essa ação irá limpar todo cache de listas de rádios  \ngeradas anteriormente.\n\nDeseja continuar ?" \
			--button "Sim":0 --button "Não":252
		
		# Limpa o cache removendo todos os arquivo .list
		# As informações principais das rádios são armazenadas nesses arquivos
		# que ficam localizados na pasta '/tmp'
		# Cada arquivo possue a extensão .list com o prefixo do nome do gênero.
		[ $? -eq 0 ] &&	rm -f /tmp/*.list &>/dev/null
	
		# Função principal	
		main
	fi

	######### LISTA DE GÊNEROS ###############
	# Gera arquivo de cache se ele não existir.
	if [ ! -e $GENRE_LIST ]; then
		# Lê a linha
		while read radio; do
			# Incrementa arquivo especifico ao gênero
			echo "$radio" >> $GENRE_LIST
			echo "# Adicionando: '$radio'"
			sleep 0.1
		# Realiza um dump na 'url', aplica uma 'ER' para obter as tags dos gêneros, alimentando o while
		# com o padrão obtido.
		done < <(curl "$SITE" 2>/dev/null | sed -n 's/class="btn/\n/gp' | sed -n 's/^.*">\(.*\)<\/a>&nbsp;.*$/\1/pg') \
				| yad --title "Gêneros" \
						--text "Sincronizando gêneros musicais..." \
						--center \
						--no-buttons \
						--auto-kill \
						--auto-close \
						--fixed \
						--width 400 \
						--progress \
						--text-progress \
						--pulsate
	fi
	
	# Lê as informações do arquivo .list redirecionando para 'yad'
	# Armazena saida em 'GENRE' 
	GENRE=$(cat $GENRE_LIST | yad --title "Gêneros" \
			--center \
			--no-buttons \
			--width 300 \
			--height 600 \
			--no-buttons \
			--text "<b>Total: $(cat "$GENRE_LIST" | wc -l)</b>" \
			--list \
			--search-column 1 \
			--listen \
			--column "Nome")

	# Se a janela for fechada.
	[ $? -eq 252 ] && main
	
	COUNT=$(echo $COUNT | cut -d'|' -f3 | cut -d',' -f1)	# Pega o(s) primeiro(s) digito(s) antes da virgula.
	GENRE="${GENRE/|/}"										# Gênero
	RADIO_LIST="/tmp/$GENRE.list"							# Arquivo .list
	tag_genre="$(echo ${GENRE/ /%20} | tr '[:upper:]' '[:lower:]')"		# Se o nome do gênero conter espaço, substitui por Encondig Reference (%20).

	######### LISTA DE RÁDIOS ###############
	# Gera arquivo de cache se ele não existir.
	if [ ! -e "$RADIO_LIST" ]; then
		for pag in $(seq $COUNT); do
			# Lê a linha
			while read radio; do
				# Incrementa arquivo
				echo "$radio" >> "$RADIO_LIST"
				# Envia somente o nome da rádio para o 'progress'
				[ "$(echo $radio | egrep -v "^http|^$GENRE$")" ] && echo "# $radio"
				sleep 0.1
			# A url é alterada dinamicamente
			# Recebendo os valores do "Gênero" e "Página".
			# O dump é realizado na 'url', aplicando uma 'ER' que obtem as tag's que contém o nome das rádios.
			done < <(curl https://www.internet-radio.com/stations/$tag_genre/page$pag 2>/dev/null | \
					 sed -n "s/^.*?mount=\(.*\)\/listen.*title=\(.*\)&.*$/\2\n$GENRE\n\1/pg") | \
						yad --title "Rádios" \
							--text "Gênero: <b>$GENRE</b>\nPágina: <b>$pag</b>\nProcurando..." \
							--center \
							--on-top \
							--no-buttons \
							--progress \
							--text-progress \
							--auto-kill \
							--auto-close \
							--fixed \
							--width 600 \
							--pulsate
		done  
	fi
	
	# Mata todos os subshell's com excessão do shell principal.
    kill -9 $(ps aux | grep "$SCRIPT" | egrep -v "grep|$$" | awk '{print $2}') &>/dev/null
	
	# Executa a música selecionada em segundo plano.
	PlayRadio $(cat "$RADIO_LIST" \
					|  yad --center \
							--title "Rádios" \
							--fixed \
							--text "<b>Total: $(($(cat "$RADIO_LIST" | wc -l)/3))</b>" \
							--width 600 --height 600  \
							--on-top \
							--no-buttons \
							--list \
							--listen \
							--search-column 1 \
							--hide-column 3 \
							--column "Nome" \
							--column "Gênero" \
							--column "Listen" \
							--separator='|') &

	# Principal
	main
}

main
