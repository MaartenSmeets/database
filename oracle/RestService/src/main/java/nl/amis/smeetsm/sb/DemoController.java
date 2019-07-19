package nl.amis.smeetsm.sb;

import oracle.jdbc.OracleArray;
import oracle.jdbc.OracleCallableStatement;
import oracle.jdbc.OracleConnection;
import oracle.jdbc.OracleStruct;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import javax.servlet.http.HttpServletRequest;
import javax.sql.DataSource;
import java.io.BufferedReader;
import java.io.IOException;
import java.math.BigDecimal;
import java.sql.*;
import java.util.*;
import java.util.stream.Collectors;

@RestController
public class DemoController {

    @Autowired
    DataSource datasource;

    @RequestMapping("/api/v1/**")
    public ResponseEntity get(HttpServletRequest request) throws SQLException, IOException {

        //Converting the HTTP request headers to a hashMap
        Enumeration<String> requestHeaders = request.getHeaderNames();
        String requestHeader;
        HashMap<String, String> requestHeadersHM = new HashMap<String, String>();
        while (requestHeaders.hasMoreElements()) {
            requestHeader = requestHeaders.nextElement();
            requestHeadersHM.put(requestHeader, request.getHeader(requestHeader));
        }

        //Creating a connection
        Connection conn;
        conn = datasource.getConnection();
        CallableStatement st = null;

        //This defines the procedure which is being called. ? are the bind parameters (P_REQUEST and P_RESPONSE)
        st = conn.prepareCall(
                "{ call GEN_REST.DISPATCHER( ?, ? ) }"
        ).unwrap(OracleCallableStatement.class);

        //Create array of headers from the HashMap in a structure the database can deal with
        ArrayList<Struct> headersStructArr = new ArrayList<Struct>();
        for (String key : requestHeadersHM.keySet()) {
            headersStructArr.add(conn.createStruct("HTTP_HEADER_TYPE", new Object[]{key, requestHeadersHM.get(key)}));
        }
        OracleArray httpHeadersArray = (OracleArray) (conn.unwrap(OracleConnection.class)).createOracleArray("HTTP_HEADERS_TYPE", headersStructArr.toArray());

        //Create an arraylist of what the REST_REQUEST_TYPE needs to be constructed. HTTP method, URI, HTTP headers and body.
        ArrayList<Object> attributes = new ArrayList();
        attributes.add(request.getMethod());
        attributes.add(request.getRequestURI());
        attributes.add(httpHeadersArray);

        //Convert the request body to a CLOB (character large object). This is a database type
        //This can be dangerous because the request data is serialized in memory. With a large request this might cause memory issues
        // For production use, implement some protection against this
        Clob clob = conn.createClob();
        clob.setString(1, request.getReader().lines().collect(Collectors.joining()));
        attributes.add(clob);

        //Create the request type
        Struct requestTypeStruct = conn.createStruct("REST_REQUEST_TYPE", attributes.toArray());

        //Register the response bind variable
        st.registerOutParameter(2, Types.STRUCT, "REST_RESPONSE_TYPE");
        st.setObject(1, requestTypeStruct);

        //Actually execute the call since preparations are done
        st.execute();

        // Process the response
        // The second parameter in the prepared statement is the OUT parameter; the response
        OracleStruct responseTypeStruct = ((OracleCallableStatement) st).getSTRUCT(2);

        //The response is an Oracle Object type
        // The first attribute of the object is a BigDecimal; the statuscode
        BigDecimal myBD= (BigDecimal)responseTypeStruct.getAttributes()[0];
        int responsestatus = myBD.toBigInteger().intValue();

        //The second attribute is an object, table of HTTP header objects
        //First get the table. next process the items in the table (the individual headers)
        httpHeadersArray = (OracleArray)responseTypeStruct.getAttributes()[1];
        Object[] resultHeaders = (Object[])httpHeadersArray.getArray();

        Object[] resultHeaderItems;
        String header_name="";
        String header_value="";

        //An individual header consists of a name and a value. Use these to set the response headers
        HttpHeaders responseHeaders = new HttpHeaders();
        for (Object resultHeader : resultHeaders) {
            resultHeaderItems = ((Struct)resultHeader).getAttributes();
            header_name = resultHeaderItems[0].toString();
            header_value = resultHeaderItems[1].toString();
            System.out.println("Setting header "+header_name+" to "+header_value);
            responseHeaders.set(header_name,header_value);
        }

        // the third and last attribute is the body of the response message. This is of type Clob and can be read as characterstream, buffered and converted to String
        // the danger here is out of memory if the message body is large (Gb's). For production use, implement some protection.
        clob=(Clob)responseTypeStruct.getAttributes()[2];
        BufferedReader myReader = new BufferedReader(clob.getCharacterStream());

        return ResponseEntity.status(responsestatus).headers(responseHeaders).body(myReader.lines().collect(Collectors.joining()));
    }
}
