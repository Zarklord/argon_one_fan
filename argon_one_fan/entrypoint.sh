#!/bin/sh

echo "*** Argon One Fan Controller Startup ***"

CalibrateI2CPort() {
  if [ -z  "$(ls /dev/i2c-*)" ]; then
    echo "Cannot find I2C port.  You must enable I2C for this to operate properly";
    exit 1;
  fi
  for device in /dev/i2c-*; do 
    port=${device:9};
    echo "checking i2c port ${port} at ${device}";
    detection=$(i2cdetect -y "${port}");
    [[ "${detection}" == *"10: -- -- -- -- -- -- -- -- -- -- 1a -- -- -- -- --"* ]] && i2cport=${port} && echo "found at $device" && break;
    [[ "${detection}" == *"10: -- -- -- -- -- -- -- -- -- -- -- 1b -- -- -- --"* ]] && i2cport=${port} && echo "found at $device" && break;
    echo "not found on ${device}"
  done;
}

FanActionLinear() {
  fan_percent=${1};
  cpu_temp=${2};
  temp_unit=${3};

  # send all hexadecimal format 0x00 > 0x64 (0>100%)
  if [[ $fan_percent -lt 10 ]]; then
    hex_fan_percent=$(printf '0x0%x' "${fan_percent}")
  else
    hex_fan_percent=$(printf '0x%x' "${fan_percent}")
  fi;

  i2cset -y "${port}" "0x01a" "${hex_fan_percent}"
}

CalibrateI2CPort;
port=${i2cport};

#Trap exits and set fan to 100% like a safe mode.
trap 'echo "Failed ${LINENO}: $BASH_COMMAND";i2cset -y ${port} 0x01a 0x63;previous_fan_level=-1;fan_level=-1; echo Safe Mode Activated!;' ERR EXIT INT TERM

if [ "${port}" == 255 ]; then
  echo "Argon One was not detected on i2c.";
else
  echo "Argon One Detected. Beginning monitor.."
fi;

fan_percent=0;
previous_fan_percent=-1;

temp_min=${MIN_TEMP}
temp_max=${MAX_TEMP}

fan_speed_temp_multiplier=$((100/(temp_max-temp_min)))
fan_speed_temp_min=$((-fan_speed_temp_multiplier*temp_min))

until false; do
  read -r raw_cpu_temp < /sys/class/thermal/thermal_zone0/temp
  cpu_temp=$(echo "scale=2; ${raw_cpu_temp}/1000" | bc -l)
  temp_unit="C"

  if [ "${TEMP_MODE}" == "F" ]; then
    cpu_temp=$(echo "scale=2; (${cpu_temp} * 9/5) + 32" | bc -l)
    temp_unit="F"
  fi
  fan_percent=$(echo "scale=2; fan_percent=${fan_speed_temp_multiplier}*${cpu_temp}+${fan_speed_temp_min}; fan_percent+=0.5; if(fan_percent<1) fan_percent=1 else if(fan_percent>100) fan_percent=100; scale=0; fan_percent/1" | bc -l)

  set +e
  if [ $previous_fan_percent != $fan_percent ]; then
    FanActionLinear "${fan_percent}" "${cpu_temp}" "${TEMP_MODE}"
    test $? -eq 0 && previous_fan_percent=$fan_percent
  fi

  if [ "${LOG_TEMP}" == "true" ]; then
    printf '[%s]: Current Temperature = %.2f°%s, Fan Speed = %d%%\n' $(date +%F_%H:%M:%S) "${cpu_temp}" "${temp_unit}" "${fan_percent}"
  fi

  if [ ! -z "${MQTT_HOST}" ]; then
    /usr/bin/mosquitto_pub -h ${MQTT_HOST} -p ${MQTT_PORT} -u ${MQTT_USERNAME} -P ${MQTT_PASSWORD} -m ${cpu_temp} -t argon_one/${MQTT_TOPIC}/temp
    /usr/bin/mosquitto_pub -h ${MQTT_HOST} -p ${MQTT_PORT} -u ${MQTT_USERNAME} -P ${MQTT_PASSWORD} -m ${fan_percent} -t argon_one/${MQTT_TOPIC}/fan_speed
  fi

  sleep 30
done
