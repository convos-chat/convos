#!/bin/bash

# Set default values, if not set in ENV
# - CONVOS_REDIS_URL
# - CONVOS_ORG_NAME
# - CONVOS_INVITE_CODE
CONVOS_ORG_NAME=${CONVOS_ORG_NAME:-'Nordaaker'}
CONVOS_INVITE_CODE=${CONVOS_INVITE_CODE:-''}

# Fill config template
convos_config=$(<convos.conf.template);
convos_config=${convos_config//##CONVOS_ORG_NAME##/$CONVOS_ORG_NAME};
convos_config=${convos_config//##CONVOS_INVITE_CODE##/$CONVOS_INVITE_CODE};

# Write config file
printf '%s\n' "$convos_config" >convos.conf
