# set -x

VULTR_API_BASE="https://api.vultr.com/v1/dns"
NDC_API_BASE="https://api.name.com/v4/domains"
NDC_AUTH=$NAMEDOTCOM_API_KEY:$NAMEDOTCOM_API_SECRET

_VULTR_ns() {
    for i in 1 2;do dig +short ns${i}.vultr.com;done
}

_VULTR_cleanup_defaults() {
    for record in $(http GET ${VULTR_API_BASE}/records\?domain\=$1 API-Key:$VULTR_API_KEY | jq '.[] | .RECORDID')
    do
        http --ignore-stdin --form POST ${VULTR_API_BASE}/delete_record API-Key:$VULTR_API_KEY domain\=$1 RECORDID\=$record
    done
}

_VULTR_dns_glue() {
    local counter=0
    for ip in $(_VULTR_ns)
    do
        local counter=$((counter+1))
        http --ignore-stdin --form POST ${VULTR_API_BASE}/create_record API-Key:$VULTR_API_KEY domain\=$1 name\="ns${counter}" type\=A data\=$ip
        http --ignore-stdin --form POST ${VULTR_API_BASE}/create_record API-Key:$VULTR_API_KEY domain\=$1 name:='""' type\=NS data\="ns${counter}.${1}"
    done
}

_VULTR_dnssec_create() {
    http --ignore-stdin --form POST ${VULTR_API_BASE}/dnssec_enable API-Key:$VULTR_API_KEY domain\=$1 enable\=yes
}


_VULTR_dnssec_info() {
    http GET ${VULTR_API_BASE}/dnssec_info\?domain\=$1 API-Key:$VULTR_API_KEY | \
        jq 'map(split(" ;";"") | .[0] | split(" ") | { keyTag: .[3], algorithm: .[4], digestType: .[5], digest: .[6]} | select(.digestType == "1" or .digestType == "2"))'
}

_NDC_dns_vanity_create() {
    local counter=0
    for ip in $(_VULTR_ns)
    do
        local counter=$((counter+1))
        jq -n --arg counter $counter --arg ip $ip --arg domain $1 '{ hostname: (("ns" + $counter + ".") + $domain), ips: [$ip] }' | \
            http POST ${NDC_API_BASE}/${1}/vanity_nameservers domainName:${1} -a $NDC_AUTH
    done
}

_NDC_dns_vanity_delete() {
    for vns in $(http GET ${NDC_API_BASE}/${1}/vanity_nameservers -a $NDC_AUTH | jq -r '.vanityNameservers | map(.hostname) | join(" ")')
    do
        http DELETE ${NDC_API_BASE}/${1}/vanity_nameservers/${vns} -a $NDC_AUTH &> /dev/null
    done
}

_NDC_dns_set_ns() {
    local domain=$1
    local counter=0
    local ns=$(for ns in $(_VULTR_ns); do counter=$((counter+1)) && echo  $counter; done)
    printf '%s\n' "${ns[@]}" | jq -R . | jq -s . | \
        jq --arg domain $domain 'map("ns" + . + ("." + $domain))' | jq '{nameservers: .}' | \
        http POST ${NDC_API_BASE}/${1}:setNameservers -a $NDC_AUTH &> /dev/null
}

_NDC_dns_delete_ns() {
    # NOTE: https://www.name.com/api-docs has no support for deleting domains, hence we reset it to name.com default.
    jq -n '{nameservers: ["ns1.name.com", "ns2.name.com"]}' | http POST ${NDC_API_BASE}/${1}:setNameservers -a $NDC_AUTH &> /dev/null
}

_NDC_dnssec_create() {
    for record in $(echo $(_VULTR_dnssec_info $1) | jq -r '.[] | tostring')
    do
        echo $record | http POST ${NDC_API_BASE}/${1}/dnssec -a $NDC_AUTH
    done
}

_NDC_dnssec_info() {
    http GET ${NDC_API_BASE}/${1}/dnssec -a $NDC_AUTH |  jq -r '.dnssec | map(.digest) | .[] | tostring'
}

_NDC_dnssec_delete() {
    for record in $(_NDC_dnssec_info $1)
    do
        echo $record | http DELETE ${NDC_API_BASE}/${1}/dnssec/$record -a $NDC_AUTH
    done
}


# Command line processing
if [[ $# -gt 2 ]] || [[ $# -eq 0 ]];then
    echo "Either 0 or more than 2 input arguments provided which is not supported"
    exit 1
fi

while [ ! -z "$1" ];do
    case "$1" in
        create)
            shift
            DOMAIN="$1"
            _VULTR_cleanup_defaults $DOMAIN
            _VULTR_dns_glue $DOMAIN
            _VULTR_dnssec_create $DOMAIN
            _NDC_dns_vanity_create $DOMAIN
            _NDC_dns_set_ns $DOMAIN
            _NDC_dnssec_create $DOMAIN
            ;;
        destroy)
            shift
            DOMAIN="$1"
            _NDC_dns_delete_ns $DOMAIN
            _NDC_dns_vanity_delete $DOMAIN
            _NDC_dnssec_delete $DOMAIN
            ;;
        *)
            echo "Incorrect input provided"
            exit 1
    esac
    shift
done
