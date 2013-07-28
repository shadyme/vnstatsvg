#!/bin/bash
# vnstat.sh -- generate an xml file from the vnStat database: $ vnstat --dumpdb -i iface
# author: falcon <zhangjinw@gmail.com>, http://dslab.lzu.edu.cn/members/falcon
# update: 2008-06-14

# print the header of xml file
echo "content-type:text/xml"
echo ""
echo "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>"


# indicate several commands
VNSTAT="/usr/bin/vnstat"

# get the arguments from a http client

ST1=$(echo "$QUERY_STRING" | cut '-d&' -f1)
ST2=$(echo "$QUERY_STRING" | cut '-d&' -f2)

IFACE=$(echo "$ST1" | cut '-d=' -f2)
PAGE=$(echo "$ST2" | cut '-d=' -f2)

# ensure the arguments are legal, NOTE: if you have other names of network interface, please add them here
[ "$IFACE" != "eth0" -a "$IFACE" != "eth1" ] && exit -1
[ "$PAGE" != "summary" -a "$PAGE" != "hour" -a "$PAGE" != "day" -a "$PAGE" != "month" -a "$PAGE" != "top10" -a "$PAGE" != "second" ] && exit -1

# for debugging
[ -z "$IFACE" ] && IFACE=eth0
[ -z "$PAGE" ] && PAGE=summary

VNSTAT=$VNSTAT" --dumpdb -i $IFACE"

# get the traffic info of every type: summary, top10, hour, day, month
case $PAGE in
	summary) info=$($VNSTAT | awk -F";" 'BEGIN{ch=strftime("%k", systime()); sub(" ","", ch);} { if($0 ~ "^total|^d;0|^m;0|^h;"ch";|^created|^updated") {if($1 ~ "^created") {printf("%s", strftime("%y/%m/%d-->", $2));} else if ($1 ~ "^updated") {printf("%s;0;0;", strftime("%y/%m/%d", $2));} else  if($1 ~ "^total") { printf("%s;", $2); if($1 ~ "txk$") printf("1\n");} else {printf("%s",$0); if($1 == "h") printf(";1\n"); else printf("\n");}}}')
	;;
	top10) info=$($VNSTAT | grep "^t;" | grep -v ";0$" | sort -t ";" -g -k3)
	;;
	hour) info=$($VNSTAT | grep "^h;" | grep -v ";0$" | sort -t ";" -g -k3)
	;;
	day) info=$($VNSTAT | grep "^d;.*1$" | sort -t ";" -g -k3)
	;;
	month) info=$($VNSTAT | grep "^m;.*1$" | sort -t ";" -g -k3)
	;;
	second) info=$(cat /proc/net/dev | grep "$IFACE" | tr ":" " " |  awk '{printf("%s %s\n", $2/1024, $10/1024);}' \
	| awk -v page="$PAGE" 'BEGIN{
		printf("<traffic id=\"content\" p=\"%s\">\n", page);
		printf("<us><u id=\"0\" sym=\" KB\" val=\"1\"/><u id=\"1\" sym=\" MB\" val=\"1024\"/><u id=\"2\" sym=\" GB\" val=\"1048576\"/></us>\n");
		}{
			printf("<r f1=\"%s\">", strftime("%H:%M:%S",systime()));
			
			r = $1/1048576;
			t = $2/1048576;
			s = ($1+$2)/1048576;
			r_unit = 2;
			t_unit = 2;
			s_unit = 2
		 	
			if(r < 1) { r=r*1024; r_unit=1; }
		        if(r < 1) { r=r*1024; r_unit=0; }
        		if(t < 1) { t=t*1024; t_unit=1; }
		        if(t < 1) { t=t*1024; t_unit=0; }
			if(s < 1) { s=s*1024; s_unit=1; }
	        	if(s < 1) { s=s*1024; s_unit=0; }

			printf("<f><s>%s</s><u>%s</u></f>\n", r, r_unit);	/* received */
			printf("<f><s>%s</s><u>%s</u></f>\n", t, t_unit);	/* transmited */
			printf("<f><s>%s</s><u>%s</u></f>\n", s, s_unit);	/* transmited */

			printf("</r>\n");
		}END{printf("</traffic>");}');
		echo $info
		exit
	;;
	*) echo "there is no page named $PAGE" && exit -1
	;;
esac

# generate the XML result

echo "$info" | tr ' ' '\n' | \
awk -v page="$PAGE" -F";" 'BEGIN{
	printf("<traffic id=\"content\" p=\"%s\"", page);
	if(page=="summary") { 
		map["d"]="today: %Y/%m/%d";map["m"]="this month: %Y/%m";map["h"]="current hour: %H:00";
	} else {
		colnum["top10"]=10;colnum["day"]=30;colnum["month"]=12;colnum["hour"]=24;
		fullmap["t"]="%y-%m-%d";fullmap["h"]="%y-%m-%d %H:00";fullmap["m"]="%y-%m";fullmap["d"]="%y-%m-%d";
		map["t"]="%m-%d";map["h"]="%H";map["m"]="%m";map["d"]="%d";
		printf(" colnum=\"%s\"", colnum[page]);
	}
	printf(">\n");
	/* print the unit "Array" */
	printf("<us><u id=\"0\" sym=\" KB\" val=\"1\"/><u id=\"1\" sym=\" MB\" val=\"1024\"/><u id=\"2\" sym=\" GB\" val=\"1048576\"/></us>\n");
	max=0;
	}{
		/* print the first column */
		if(page=="summary") {
			if ($1 ~ "d|m|h") printf("<r f1=\"%s\"", strftime(map[$1], systime()));
			else printf("<r f1=\"%s\"", $1);
		} else {
			printf("<r f1=\"%s\" x=\"%s\"", strftime(fullmap[$1], $3), strftime(map[$1], $3));
		}
					/* count the size and unit of receive, transmit, s traffic flow */
		if($1 == "h") {
			r=$4/1048576;
        	        t=$5/1048576;
		} else {
			r=($4*1024+$6)/1048576;
        	        t=($5*1024+$7)/1048576;
                }
		
		if (r > max) max=r;
		if (t > max) max=t;
        	s=r+t;
					/* unit, GB 1048576, MB 1024, KB 1, here we use 3, 2, 1 instead to reduce the size of XML file */
	        s_unit=2;
        	r_unit=2;
	        t_unit=2;
        	if(s < 1) { s=s*1024; s_unit=1; }
	        if(s < 1) { s=s*1024; s_unit=0; }
	        if(r < 1) { r=r*1024; r_unit=1; }
        	if(r < 1) { r=r*1024; r_unit=0; }
	        if(t < 1) { t=t*1024; t_unit=1; }
	        if(t < 1) { t=t*1024; t_unit=0; }

		printf(">");
		printf("<f><s>%s</s><u>%s</u></f>",r, r_unit);	/* receive */
		printf("<f><s>%s</s><u>%s</u></f>",t, t_unit);	/* transmit */
		printf("<f><s>%s</s><u>%s</u></f>",s, s_unit);	/* total(sum) */
		printf("</r>\n");
	}END{
		if(page != "summary") {
			max_unit=2;
			if(max < 1) { max=max*1024; max_unit=1; }
		       	if(max < 1) { max=max*1024; max_unit=0; } 
			printf("<mf><s>%s</s><u>%s</u></mf>\n",max, max_unit);
		}
	}'
echo "</traffic>"