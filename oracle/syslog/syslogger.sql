SET DEFINE OFF
create or replace and compile
 java source named "SysLogger"
 as
//Syslog - Unix-compatible syslog routines
//
//Original version by Tim Endres, <time@ice.com>.
//
//Re-written and fixed up by Jef Poskanzer <jef@acme.com>.
//
//Re-written again by Maarten Smeets. 
//
//Copyright (C) 2019 by Maarten Smeets.  All rights reserved.
//
//Redistribution and use in source and binary forms, with or without
//modification, are permitted provided that the following conditions
//are met:
//1. Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
//2. Redistributions in binary form must reproduce the above copyright
// notice, this list of conditions and the following disclaimer in the
// documentation and/or other materials provided with the distribution.
//
//THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
//ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
//FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
//OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
//HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
//LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
//OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
//SUCH DAMAGE.

import java.io.*;
import java.net.*;
import java.util.*;

//Unix-compatible syslog routines.
//<P>
/// The Syslog class implements the Unix syslog protocol allowing Java
//to log messages to the standard syslog files. Care has been taken to
//preserve as much of the Unix implementation as possible.
//<p>
//To use Syslog, simply create an instance, and use the syslog() method
//to log your message. The class provides all the expected syslog constants.
//For example, LOG_ERR is Syslog.LOG_ERR.
//<P>
//Original version by <A HREF="http://www.ice.com/~time/">Tim Endres</A><BR>
//<A HREF="/resources/classes/Acme/Syslog.java">Fetch the software.</A><BR>
//<A HREF="/resources/classes/Acme.tar.Z">Fetch the entire Acme package.</A>

public class Syslog {

	// Priorities.
	public static final int LOG_EMERG = 0; // system is unusable
	public static final int LOG_ALERT = 1; // action must be taken immediately
	public static final int LOG_CRIT = 2; // critical conditions
	public static final int LOG_ERR = 3; // error conditions
	public static final int LOG_WARNING = 4; // warning conditions
	public static final int LOG_NOTICE = 5; // normal but significant condition
	public static final int LOG_INFO = 6; // informational
	public static final int LOG_DEBUG = 7; // debug-level messages
	public static final int LOG_PRIMASK = 0x0007; // mask to extract priority

	// Facilities.
	public static final int LOG_KERN = (0 << 3); // kernel messages
	public static final int LOG_USER = (1 << 3); // random user-level messages
	public static final int LOG_MAIL = (2 << 3); // mail system
	public static final int LOG_DAEMON = (3 << 3); // system daemons
	public static final int LOG_AUTH = (4 << 3); // security/authorization
	public static final int LOG_SYSLOG = (5 << 3); // internal syslogd use
	public static final int LOG_LPR = (6 << 3); // line printer subsystem
	public static final int LOG_NEWS = (7 << 3); // network news subsystem
	public static final int LOG_UUCP = (8 << 3); // UUCP subsystem
	public static final int LOG_CRON = (15 << 3); // clock daemon
	// Other codes through 15 reserved for system use.
	public static final int LOG_LOCAL0 = (16 << 3); // reserved for local use
	public static final int LOG_LOCAL1 = (17 << 3); // reserved for local use
	public static final int LOG_LOCAL2 = (18 << 3); // reserved for local use
	public static final int LOG_LOCAL3 = (19 << 3); // reserved for local use
	public static final int LOG_LOCAL4 = (20 << 3); // reserved for local use
	public static final int LOG_LOCAL5 = (21 << 3); // reserved for local use
	public static final int LOG_LOCAL6 = (22 << 3); // reserved for local use
	public static final int LOG_LOCAL7 = (23 << 3); // reserved for local use

	public static final int LOG_FACMASK = 0x03F8; // mask to extract facility

	// Option flags.
	public static final int LOG_PID = 0x01; // log the pid with each message
	public static final int LOG_CONS = 0x02; // log on the console if errors
	public static final int LOG_NDELAY = 0x08; // don't delay open
	public static final int LOG_NOWAIT = 0x10; // don't wait for console forks

	private static final int DEFAULT_PORT = 514;

	public final static byte[] asBytes(String addr) {

    // Convert the TCP/IP address string to an integer value

    int ipInt = parseNumericAddress(addr);
    if (ipInt == 0)
        return null;

    // Convert to bytes

    byte[] ipByts = new byte[4];

    ipByts[3] = (byte) (ipInt & 0xFF);
    ipByts[2] = (byte) ((ipInt >> 8) & 0xFF);
    ipByts[1] = (byte) ((ipInt >> 16) & 0xFF);
    ipByts[0] = (byte) ((ipInt >> 24) & 0xFF);

    // Return the TCP/IP bytes

    return ipByts;
	}

	/**
	* Check if the specified address is a valid numeric TCP/IP address and return as an integer value
	*
	* @param ipaddr String
	* @return int
	*/
	public final static int parseNumericAddress(String ipaddr) {

    //  Check if the string is valid

    if (ipaddr == null || ipaddr.length() < 7 || ipaddr.length() > 15)
        return 0;

    //  Check the address string, should be n.n.n.n format

    StringTokenizer token = new StringTokenizer(ipaddr, ".");
    if (token.countTokens() != 4)
        return 0;

    int ipInt = 0;

    while (token.hasMoreTokens()) {

        //  Get the current token and convert to an integer value

        String ipNum = token.nextToken();

        try {

            //  Validate the current address part

            int ipVal = Integer.valueOf(ipNum).intValue();
            if (ipVal < 0 || ipVal > 255)
                return 0;

            //  Add to the integer address

            ipInt = (ipInt << 8) + ipVal;
        } catch (NumberFormatException ex) {
            return 0;
        }
    }

    //  Return the integer address
    return ipInt;
	}
	
	/// Use this method to log your syslog messages. The facility and
	// level are the same as their Unix counterparts, and the Syslog
	// class provides constants for these fields. The msg is what is
	// actually logged.
	// @exception SyslogException if there was a problem
	@SuppressWarnings("deprecation")
	public static String syslog(String hostname, Integer port, String ident, Integer facility, Integer priority, String msg) {
		try {
			InetAddress address;
			if (hostname == null) {
				address = InetAddress.getLocalHost();
			} else {
				byte[] myBytes = asBytes(hostname);
				if (myBytes==null) {
					address = InetAddress.getByName(hostname);
				} else {
					address = InetAddress.getByAddress(myBytes);
				}
			}

			if (port == null) {
				port = new Integer(DEFAULT_PORT);
			}
			if (facility == null) {
				facility = 1; // means user-level messages
			}
			if (ident == null)
				ident = new String(Thread.currentThread().getName());

			int pricode;
			int length;
			int idx;
			byte[] data;
			String strObj;

			pricode = MakePriorityCode(facility, priority);
			Integer priObj = new Integer(pricode);

			length = 4 + ident.length() + msg.length() + 1;
			length += (pricode > 99) ? 3 : ((pricode > 9) ? 2 : 1);

			data = new byte[length];

			idx = 0;
			data[idx++] = '<';

			strObj = Integer.toString(priObj.intValue());
			strObj.getBytes(0, strObj.length(), data, idx);
			idx += strObj.length();

			data[idx++] = '>';

			ident.getBytes(0, ident.length(), data, idx);
			idx += ident.length();

			data[idx++] = ':';
			data[idx++] = ' ';

			msg.getBytes(0, msg.length(), data, idx);
			idx += msg.length();

			data[idx] = 0;

			DatagramPacket packet = new DatagramPacket(data, length, address, port);
			DatagramSocket socket = new DatagramSocket();
			socket.send(packet);
			socket.close();
		} catch (IOException e) {
			return "error sending message: '" + e.getMessage() + "'";
		}
		return "";
	}

	private static int MakePriorityCode(int facility, int priority) {
		return ((facility & LOG_FACMASK) | priority);
	}
}
/
create or replace
procedure SYSLOGGER(p_hostname in varchar2, p_port in number, p_ident in varchar2, p_facility in number, p_priority in number, p_msg in varchar2)
as
language java
name 'Syslog.syslog(java.lang.String,java.lang.Integer,java.lang.String,java.lang.Integer,java.lang.Integer,java.lang.String)';
/
