//in /etc/rsyslog.conf uncomment
//$ModLoad imudp
//$UDPServerRun 514

//for function:
select SYSLOGGER('127.0.0.1', 514, 'syslogtest', 1, 5, 'Hello there') from dual;
//for procedure
DECLARE
  P_HOSTNAME VARCHAR2(200);
  P_PORT NUMBER;
  P_IDENT VARCHAR2(200);
  P_FACILITY NUMBER;
  P_PRIORITY NUMBER;
  P_MSG VARCHAR2(200);
BEGIN
  P_HOSTNAME := NULL;
  P_PORT := NULL;
  P_IDENT := 'Syslogtest';
  P_FACILITY := NULL;
  P_PRIORITY := 1;
  P_MSG := 'Hi there';

  SYSLOGGER(
    P_HOSTNAME => P_HOSTNAME,
    P_PORT => P_PORT,
    P_IDENT => P_IDENT,
    P_FACILITY => P_FACILITY,
    P_PRIORITY => P_PRIORITY,
    P_MSG => P_MSG
  );
--rollback; 
END;
