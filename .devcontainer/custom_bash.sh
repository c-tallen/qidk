# Source Qualcomm QAIRT environment setup
QAIRT_ENV_SCRIPT="/opt/qairt/2.34.0.250424/bin/envsetup.sh"
if [ -f "${QAIRT_ENV_SCRIPT}" ]; then
  echo "Sourcing QAIRT environment from ${QAIRT_ENV_SCRIPT}..."
  . "${QAIRT_ENV_SCRIPT}"
else
  echo "WARNING: QAIRT envsetup.sh not found at ${QAIRT_ENV_SCRIPT}"
fi

