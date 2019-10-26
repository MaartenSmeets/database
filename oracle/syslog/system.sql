create user testuser identified by Welcome01;
/
grant connect,dba,resource to testuser;
/
begin
dbms_java.grant_permission( 'TESTUSER', 'SYS:java.net.SocketPermission', 'localhost:0', 'listen,resolve' );
dbms_java.grant_permission( 'TESTUSER', 'SYS:java.net.SocketPermission', '127.0.0.1:514', 'connect,resolve' );
end;
/
