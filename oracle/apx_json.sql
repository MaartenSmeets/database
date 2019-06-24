set define off

create or replace type apx_t_writer as object (
--------------------------------------------------------------------------------
--
--  Copyright (c) Oracle Corporation 1999 - 2013. All Rights Reserved.
--
--    NAME
--      apx_t_writer.sql
--
--    DESCRIPTION
--      Object type that can write to some resource. This is the root of a type
--      hierarchy. Only the subtypes are instantiable.
--
--    EXAMPLE
--      procedure print_data(p_writer in out nocopy apex_t_writer)
--      is
--      begin
--          -- 'Hello Oracle'||chr(10)
--          p_writer.prn('Hello');
--          p_writer.p(' Oracle');
--          -- 'Hello "APEX"'||chr(10)
--          p_writer.prnf('Hello "%s"%s', 'APEX', chr(10));
--      end;
--
--    SEE ALSO
--      type apex_t_clob_writer: subtype which writes to a clob
--      type apex_t_blob_writer: subtype which writes to a blob
--      type apex_t_htp_writer: subtype which writes via sys.htp
--
--    RUNTIME DEPLOYMENT: YES
--    PUBLIC:             YES
--
--    MODIFIED   (MM/DD/YYYY)
--    cneumuel    08/22/2013 - Created
--    cneumuel    12/02/2014 - Made p% and prn% members final, because calling is faster
--
--------------------------------------------------------------------------------

--==============================================================================
-- internal attributes for buffering output (may not be used by all subtypes)
--==============================================================================
l_temp        varchar2(32767 byte),
l_temp_length number,

--==============================================================================
-- constructor
--==============================================================================
constructor function apx_t_writer (
    self in out nocopy apx_t_writer )
    return self as result,

--==============================================================================
-- free the resource
--==============================================================================
member procedure free (
    self in out nocopy apx_t_writer ),

--==============================================================================
-- write any pending changes, in case the writer does caching
--==============================================================================
member procedure flush (
    self in out nocopy apx_t_writer ),

--==============================================================================
-- internal prn routine - do not use directly
--==============================================================================
final member procedure prn_internal (
    self          in out nocopy apx_t_writer,
    p_text        in varchar2,
    p_text_length in number ),

--==============================================================================
-- write a string, without line break
--==============================================================================
final member procedure prn (
    self   in out nocopy apx_t_writer,
    p_text in varchar2 ),

--==============================================================================
-- write a clob, without line break
--==============================================================================
final member procedure prn (
    self   in out nocopy apx_t_writer,
    p_text in clob ),

--==============================================================================
-- write a formatted string, without line break (simplified fprintf)
--
-- every i-th position of '%s' in p_text gets replaced by the p<i-1>. For
-- example,
--
--   l_writer.prnf('Hello %s Version "%d"', 'APEX', 5);
--
-- is equivalent to
--
--   l_writer.prn('Hello '||'APEX'||' Version "'||5||'"');
--
-- but easier to read. Further, every pi and p_text can be up to 32k, while
-- concatenation of long varchar2 might cause an error.
--==============================================================================
final member procedure prnf (
    self   in out nocopy apx_t_writer,
    p_text in varchar2,
    p0     in varchar2,
    p1     in varchar2 default null,
    p2     in varchar2 default null,
    p3     in varchar2 default null,
    p4     in varchar2 default null,
    p5     in varchar2 default null,
    p6     in varchar2 default null,
    p7     in varchar2 default null,
    p8     in varchar2 default null,
    p9     in varchar2 default null ),

--==============================================================================
-- write a string, and a line break
--==============================================================================
final member procedure p (
    self   in out nocopy apx_t_writer,
    p_text in varchar2 ),

--==============================================================================
-- write a clob, and a line break
--==============================================================================
final member procedure p (
    self   in out nocopy apx_t_writer,
    p_text in clob ),

--==============================================================================
-- write a formatted string, with line break (simplified fprintf)
--
-- every i-th position of '%s' in p_text gets replaced by the p<i-1>. For
-- example,
--
--   l_writer.p('Hello %s Version "%d"', 'APEX', 5);
--
-- is equivalent to
--
--   l_writer.p('Hello '||'APEX'||' Version "'||5||'"');
--
-- but easier to read. Further, every pi and p_text can be up to 32k, while
-- concatenation of long varchar2 might cause an error.
--==============================================================================
final member procedure pf (
    self   in out nocopy apx_t_writer,
    p_text in varchar2,
    p0     in varchar2,
    p1     in varchar2 default null,
    p2     in varchar2 default null,
    p3     in varchar2 default null,
    p4     in varchar2 default null,
    p5     in varchar2 default null,
    p6     in varchar2 default null,
    p7     in varchar2 default null,
    p8     in varchar2 default null,
    p9     in varchar2 default null ),

FINAL MEMBER FUNCTION NEXT_CHUNK (
    P_STR    IN            CLOB,
    P_CHUNK  OUT           NOCOPY VARCHAR2,
    P_OFFSET IN OUT NOCOPY PLS_INTEGER,
    P_AMOUNT IN            PLS_INTEGER DEFAULT 8191 )
    RETURN BOOLEAN

) not instantiable not final;
/
create or replace TYPE BODY apx_t_writer AS

CONSTRUCTOR FUNCTION apx_T_WRITER (
    SELF IN OUT NOCOPY apx_T_WRITER )
    RETURN SELF AS RESULT
IS
BEGIN
    SELF.L_TEMP_LENGTH := 0;
    RETURN;
END apx_T_WRITER;


MEMBER PROCEDURE FREE (
    SELF IN OUT NOCOPY apx_T_WRITER )
IS
BEGIN
    SELF.L_TEMP_LENGTH := 0;
    SELF.L_TEMP        := NULL;
END FREE;


MEMBER PROCEDURE FLUSH (
    SELF IN OUT NOCOPY apx_T_WRITER )
IS
BEGIN
    SELF.L_TEMP_LENGTH := 0;
    SELF.L_TEMP        := NULL;
END FLUSH;


FINAL MEMBER PROCEDURE PRN_INTERNAL (
    SELF          IN OUT NOCOPY apx_T_WRITER,
    P_TEXT        IN VARCHAR2,
    P_TEXT_LENGTH IN NUMBER )
IS
BEGIN
    IF P_TEXT_LENGTH > 0 THEN
        IF SELF.L_TEMP_LENGTH = 0 THEN
            SELF.L_TEMP        := P_TEXT;
            SELF.L_TEMP_LENGTH := P_TEXT_LENGTH;
        ELSIF P_TEXT_LENGTH + SELF.L_TEMP_LENGTH <= 32767 THEN
            SELF.L_TEMP        := SELF.L_TEMP||P_TEXT;
            SELF.L_TEMP_LENGTH := SELF.L_TEMP_LENGTH + P_TEXT_LENGTH;
        ELSE
            FLUSH;
            SELF.L_TEMP        := P_TEXT;
            SELF.L_TEMP_LENGTH := P_TEXT_LENGTH;
        END IF;
    END IF;
END PRN_INTERNAL;


FINAL MEMBER PROCEDURE PRN (
    SELF IN OUT NOCOPY apx_T_WRITER,
    P_TEXT IN VARCHAR2 )
IS
BEGIN
    IF P_TEXT IS NULL THEN RETURN; END IF;

    PRAGMA INLINE(PRN_INTERNAL, 'YES');
    SELF.PRN_INTERNAL (
        P_TEXT        => P_TEXT,
        P_TEXT_LENGTH => LENGTHB(P_TEXT) );
END PRN;


FINAL MEMBER FUNCTION NEXT_CHUNK (
    P_STR    IN            CLOB,
    P_CHUNK  OUT           NOCOPY VARCHAR2,
    P_OFFSET IN OUT NOCOPY PLS_INTEGER,
    P_AMOUNT IN            PLS_INTEGER DEFAULT 8191 )
    RETURN BOOLEAN
IS
    L_OFFSET PLS_INTEGER;
    L_AMOUNT PLS_INTEGER := P_AMOUNT;
BEGIN
    IF P_STR IS NULL THEN
        RETURN FALSE;
    END IF;

    IF P_OFFSET > 0 THEN
        L_OFFSET := P_OFFSET;
    ELSE
        L_OFFSET := 1;
    END IF;

    SYS.DBMS_LOB.READ (
        LOB_LOC => P_STR,
        AMOUNT  => L_AMOUNT,
        OFFSET  => L_OFFSET,
        BUFFER  => P_CHUNK );
    P_OFFSET := L_OFFSET + L_AMOUNT;
    RETURN TRUE;
EXCEPTION WHEN NO_DATA_FOUND THEN
    RETURN FALSE;
WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20001,'next_chunk(ofs='||L_OFFSET||',amt='||L_AMOUNT||'):'||SQLERRM);
END NEXT_CHUNK;


FINAL MEMBER PROCEDURE PRN (
    SELF IN OUT NOCOPY apx_T_WRITER,
    P_TEXT IN CLOB )
IS
    L_TEXT_LENGTH NUMBER;
    L_CHUNK       VARCHAR2(32767);
    L_OFFSET      NUMBER;
BEGIN
    WHILE NEXT_CHUNK (
              P_STR    => P_TEXT,
              P_CHUNK  => L_CHUNK,
              P_OFFSET => L_OFFSET )
    LOOP
        PRAGMA INLINE(PRN_INTERNAL, 'YES');
        SELF.PRN_INTERNAL (
            P_TEXT        => L_CHUNK,
            P_TEXT_LENGTH => LENGTHB(L_CHUNK) );
    END LOOP;
END PRN;


FINAL MEMBER PROCEDURE PRNF (
    SELF   IN OUT NOCOPY apx_T_WRITER,
    P_TEXT IN VARCHAR2,
    P0     IN VARCHAR2,
    P1     IN VARCHAR2 DEFAULT NULL,
    P2     IN VARCHAR2 DEFAULT NULL,
    P3     IN VARCHAR2 DEFAULT NULL,
    P4     IN VARCHAR2 DEFAULT NULL,
    P5     IN VARCHAR2 DEFAULT NULL,
    P6     IN VARCHAR2 DEFAULT NULL,
    P7     IN VARCHAR2 DEFAULT NULL,
    P8     IN VARCHAR2 DEFAULT NULL,
    P9     IN VARCHAR2 DEFAULT NULL )
IS
    L_START PLS_INTEGER;
    L_POS   PLS_INTEGER;
    L_PI    PLS_INTEGER;
    L_LEN   PLS_INTEGER;
BEGIN
    IF P_TEXT IS NULL THEN RETURN; END IF;

    L_START := 1;
    L_PI    := 0;
    LOOP
        L_POS := INSTR(P_TEXT, '%s', L_START);
        IF L_POS = 0 THEN




            IF L_START = 1 THEN
                PRAGMA INLINE(PRN, 'YES');
                SELF.PRN (
                    P_TEXT => P_TEXT );
            ELSE
                PRAGMA INLINE(PRN, 'YES');
                SELF.PRN (
                    P_TEXT => SUBSTR (
                                P_TEXT,
                                L_START ));
            END IF;
            EXIT;
        END IF;



        L_LEN := L_POS - L_START;
        IF L_LEN > 0 THEN
            PRAGMA INLINE(PRN, 'YES');
            SELF.PRN (
                P_TEXT => SUBSTR (
                              P_TEXT,
                              L_START,
                              L_LEN ));
        END IF;



        PRAGMA INLINE(PRN, 'YES');
        SELF.PRN (
            P_TEXT => CASE L_PI
                        WHEN 0 THEN P0
                        WHEN 1 THEN P1
                        WHEN 2 THEN P2
                        WHEN 3 THEN P3
                        WHEN 4 THEN P4
                        WHEN 5 THEN P5
                        WHEN 6 THEN P6
                        WHEN 7 THEN P7
                        WHEN 8 THEN P8
                        WHEN 9 THEN P9
                    END );
        L_PI := L_PI + 1;



        L_START := L_POS + 2;
    END LOOP;
END PRNF;


FINAL MEMBER PROCEDURE P (
    SELF IN OUT NOCOPY apx_T_WRITER,
    P_TEXT IN VARCHAR2 )
IS
    L_TEXT_LENGTH NUMBER := NVL(LENGTHB(P_TEXT), 0);
BEGIN
    SELF.PRN_INTERNAL (
        P_TEXT        => P_TEXT,
        P_TEXT_LENGTH => L_TEXT_LENGTH );
    SELF.PRN_INTERNAL (
        P_TEXT        => unistr('\000a'),
        P_TEXT_LENGTH => 1 );
END P;


FINAL MEMBER PROCEDURE P (
    SELF IN OUT NOCOPY apx_T_WRITER,
    P_TEXT IN CLOB )
IS
BEGIN
    PRAGMA INLINE(PRN, 'YES');
    SELF.PRN (
        P_TEXT       => P_TEXT );
    SELF.PRN_INTERNAL (
        P_TEXT        => unistr('\000a'),
        P_TEXT_LENGTH => 1 );
END P;


FINAL MEMBER PROCEDURE PF (
    SELF   IN OUT NOCOPY apx_T_WRITER,
    P_TEXT IN VARCHAR2,
    P0     IN VARCHAR2,
    P1     IN VARCHAR2 DEFAULT NULL,
    P2     IN VARCHAR2 DEFAULT NULL,
    P3     IN VARCHAR2 DEFAULT NULL,
    P4     IN VARCHAR2 DEFAULT NULL,
    P5     IN VARCHAR2 DEFAULT NULL,
    P6     IN VARCHAR2 DEFAULT NULL,
    P7     IN VARCHAR2 DEFAULT NULL,
    P8     IN VARCHAR2 DEFAULT NULL,
    P9     IN VARCHAR2 DEFAULT NULL )
IS
BEGIN
    PRAGMA INLINE(PRNF, 'YES');
    SELF.PRNF (
        P_TEXT => P_TEXT||unistr('\000a'),
        P0     => P0,
        P1     => P1,
        P2     => P2,
        P3     => P3,
        P4     => P4,
        P5     => P5,
        P6     => P6,
        P7     => P7,
        P8     => P8,
        P9     => P9 );
END PF;

END;
/
create or replace type apx_t_htp_writer under apx_t_writer (
--------------------------------------------------------------------------------
--
--  Copyright (c) Oracle Corporation 1999 - 2013. All Rights Reserved.
--
--    NAME
--      apx_t_htp_writer.sql
--
--    DESCRIPTION
--      apex_t_writer type that writes via sys.htp. the output is buffered. if
--      code also uses the sys.htp APIs directly, flush() needs to be called
--      to write the buffer out to sys.htp.
--
--    SEE ALSO
--      type apex_t_writer: parent type
--
--    RUNTIME DEPLOYMENT: YES
--    PUBLIC:             YES
--
--    MODIFIED   (MM/DD/YYYY)
--    cneumuel    08/22/2013 - Created
--
--------------------------------------------------------------------------------

--==============================================================================
-- constructor
--
-- EXAMPLE
--
-- declare
--     l_writer apex_t_htp_writer := apex_t_htp_writer();
-- begin
--     l_writer.p('hello world');
--     l_writer.flush;
--     sys.htp.p('direct output - flush of buffered writer necessary');
--     l_writer.p('continue in buffered mode');
--     l_writer.flush;
-- end;
--==============================================================================
constructor function apx_t_htp_writer (
    self           in out nocopy apx_t_htp_writer )
    return self as result,

--==============================================================================
-- write pending changes via htp.prn
--==============================================================================
overriding member procedure flush (
    self in out nocopy apx_t_htp_writer )
)
/
create or replace TYPE BODY apx_t_htp_writer AS

CONSTRUCTOR FUNCTION apx_T_HTP_WRITER (
    SELF           IN OUT NOCOPY apx_T_HTP_WRITER )
    RETURN SELF AS RESULT
IS
BEGIN
    SELF.L_TEMP_LENGTH     := 0;
    SELF.L_TEMP            := NULL;
    RETURN;
END apx_T_HTP_WRITER;

OVERRIDING MEMBER PROCEDURE FLUSH (
    SELF IN OUT NOCOPY apx_T_HTP_WRITER )
IS
BEGIN
    IF SELF.L_TEMP_LENGTH > 0 THEN
        SYS.HTP.PRN(SELF.L_TEMP);
        SELF.L_TEMP_LENGTH := 0;
        SELF.L_TEMP        := NULL;
    END IF;
END FLUSH;

END;
/
create or replace type apx_t_clob_writer under apx_t_writer (
--------------------------------------------------------------------------------
--
--  Copyright (c) Oracle Corporation 1999 - 2013. All Rights Reserved.
--
--    NAME
--      apx_t_clob_writer.sql
--
--    DESCRIPTION
--      apex_t_writer type that writes to a clob
--
--    SEE ALSO
--      type apex_t_writer: parent type
--
--    RUNTIME DEPLOYMENT: YES
--    PUBLIC:             YES
--
--    MODIFIED   (MM/DD/YYYY)
--    cneumuel    08/22/2013 - Created
--    cneumuel    11/10/2014 - Defer createTemporary to flush procedure. if called in constructor, this leaks an empty lob
--
--------------------------------------------------------------------------------

--==============================================================================
-- the clob value
--==============================================================================
l_clob     clob,
l_cache_01 number,
l_dur      number,

--==============================================================================
-- constructor that creates a temporary clob
--
-- EXAMPLE: create writer to temporary clob
--
-- declare
--     l_writer apex_t_clob_writer := apex_t_clob_writer(p_cache=>true);
-- begin
--     l_writer.p('updating l_writer''s cache');
--     dbms_output.put_line(l_writer.get_value);
--     l_writer.free;
-- end;
--
-- EXAMPLE: create clob writer and populate from table
--
-- declare
--     l_writer apex_t_clob_writer := apex_t_clob_writer();
-- begin
--     select my_clob into l_writer.l_clob
--       from my_table
--      where id = 1;
--     --
--     l_writer.p('directly updating my_table.my_clob');
-- end;
--==============================================================================
constructor function apx_t_clob_writer (
    self        in out nocopy apx_t_clob_writer,
    p_cache     in boolean     default true,
    p_dur       in pls_integer default null )
    return self as result,

--==============================================================================
-- free the temporary clob
--==============================================================================
overriding member procedure free (
    self in out nocopy apx_t_clob_writer ),

--==============================================================================
-- write any pending changes to l_clob
--==============================================================================
overriding member procedure flush (
    self in out nocopy apx_t_clob_writer ),

--==============================================================================
-- flush changes and return the clob value
--==============================================================================
member function get_value (
    self in out nocopy apx_t_clob_writer )
    return clob,

--==============================================================================
-- return the value as varchar2 only when it does not exceed 32k; NULL otherwise
-- can be used to avoid creating a CLOB instance
--==============================================================================
member function get_value_varchar2 (
    self in out nocopy apx_t_clob_writer )
    return varchar2
)
/
create or replace TYPE BODY apx_t_clob_writer AS

CONSTRUCTOR FUNCTION apx_T_CLOB_WRITER (
    SELF        IN OUT NOCOPY apx_T_CLOB_WRITER,
    P_CACHE     IN BOOLEAN     DEFAULT TRUE,
    P_DUR       IN PLS_INTEGER DEFAULT NULL )
    RETURN SELF AS RESULT
IS
BEGIN
    SELF.L_CLOB        := NULL;
    SELF.L_CACHE_01    := CASE WHEN P_CACHE THEN 1 ELSE 0 END;
    SELF.L_DUR         := NVL(P_DUR, SYS.DBMS_LOB.CALL);
    SELF.L_TEMP_LENGTH := 0;
    SELF.L_TEMP        := NULL;

    RETURN;
END apx_T_CLOB_WRITER;


OVERRIDING MEMBER PROCEDURE FREE (
    SELF IN OUT NOCOPY apx_T_CLOB_WRITER )
IS
BEGIN
    IF SELF.L_CLOB IS NOT NULL
       AND SYS.DBMS_LOB.ISTEMPORARY (
               LOB_LOC => SELF.L_CLOB ) = 1
    THEN
        SYS.DBMS_LOB.FREETEMPORARY (
            LOB_LOC => SELF.L_CLOB );
    END IF;

    SELF.L_CLOB        := NULL;
    SELF.L_TEMP_LENGTH := 0;
    SELF.L_TEMP        := NULL;
END FREE;


OVERRIDING MEMBER PROCEDURE FLUSH (
    SELF IN OUT NOCOPY apx_T_CLOB_WRITER )
IS
BEGIN
    IF SELF.L_TEMP_LENGTH > 0 THEN
        IF SELF.L_CLOB IS NULL THEN
            SYS.DBMS_LOB.CREATETEMPORARY (
                LOB_LOC => SELF.L_CLOB,
                CACHE   => SELF.L_CACHE_01 = 1,
                DUR     => SELF.L_DUR );
        END IF;




        SYS.DBMS_LOB.WRITEAPPEND (
            LOB_LOC => SELF.L_CLOB,
            AMOUNT  => LENGTH2(SELF.L_TEMP),
            BUFFER  => SELF.L_TEMP );

        SELF.L_TEMP_LENGTH := 0;
        SELF.L_TEMP        := NULL;
    END IF;
END FLUSH;


MEMBER FUNCTION GET_VALUE (
    SELF IN OUT NOCOPY apx_T_CLOB_WRITER )
    RETURN CLOB
IS
BEGIN
    SELF.FLUSH;
    RETURN SELF.L_CLOB;
END GET_VALUE;


MEMBER FUNCTION GET_VALUE_VARCHAR2 (
    SELF IN OUT NOCOPY apx_T_CLOB_WRITER )
    RETURN VARCHAR2
IS
BEGIN
    IF SELF.L_CLOB IS NULL THEN
        RETURN SELF.L_TEMP;
    ELSE
        RETURN NULL;
    END IF;
END GET_VALUE_VARCHAR2;


END;
/
create or replace PACKAGE            apx_json authid current_user as

type vc_arr2 is table of varchar2(32767) index by binary_integer;
type vc_map  is table of varchar2(32767) index by varchar2(255);
type n_arr   is table of number          index by binary_integer;
type d_arr   is table of date            index by binary_integer;
type b_arr   is table of boolean         index by binary_integer;
subtype t_char is char(1 char);                     -- a single character
type apx_t_number is table of number;
type apx_t_varchar2 is table of varchar2(32767);
--------------------------------------------------------------------------------
--
--  Copyright (c) Oracle Corporation 1999 - 2018. All Rights Reserved.
--
--    NAME
--      apx_json.sql
--
--    DESCRIPTION
--      This package provides utilities for parsing and generating JSON.
--
--      To read from a string that contains JSON data, first use parse() to
--      convert the string to an internal format. Then use the get_% routines
--      (e.g. get_varchar2(), get_number(), ...) to access the data and
--      find_paths_like() to search.
--
--      Alternatively, use to_xmltype() to convert a JSON string to an xmltype.
--
--      This package also contains procedures to generate JSON-formatted
--      output. Use the overloaded open_%(), close_%() and write() procedures
--      for writing to the SYS.HTP buffer. To write to a temporary CLOB instead,
--      use initialize_clob_output(), get_clob_output() and free_output() for
--      managing the output buffer.
--
--    EXAMPLE 1
--      Parse a JSON string and print the value of member variable "a".
--
--        declare
--            s varchar2(32767) := '{ "a": 1, "b": ["hello", "world"]}';
--        begin
--            apx_JSON.parse(s);
--            sys.dbms_output.put_line('a is '||apx_JSON.get_varchar2(p_path => 'a'));
--        end;
--
--      Output:
--
--        a is 1
--
--    EXAMPLE 2
--      Convert a JSON string to XML and use XMLTABLE to query member values.
--
--        select col1, col2
--        from xmltable (
--            '/json/row'
--            passing apx_JSON.to_xmltype('[{"col1": 1, "col2": "hello"},'||
--                                          '{"col1": 2, "col2": "world"}]')
--            columns
--                col1 number path '/row/col1',
--                col2 varchar2(5) path '/row/col2' );
--
--      Output:
--
--        COL1 COL2
--        ---- -----
--           1 hello
--           2 world
--
--    EXAMPLE 3
--      Write a nested JSON object to the HTP buffer.
--
--        begin
--            apx_JSON.open_object;        -- {
--            apx_JSON.  write('a', 1);    --   "a":1
--            apx_JSON.  open_array('b');  --  ,"b":[
--            apx_JSON.    open_object;    --    {
--            apx_JSON.      write('c',2); --      "c":2
--            apx_JSON.    close_object;   --    }
--            apx_JSON.    write('hello'); --   ,"hello"
--            apx_JSON.    write('world'); --   ,"world"
--            apx_JSON.close_all;          --  ]
--                                          -- }
--        end;
--
--      Output:
--
--        {
--        "a":1
--        ,"b":[
--        {
--        "c":2
--        }
--        ,"hello"
--        ,"world"
--        ]
--        }
--
--    EXAMPLE 4
--      Generate and parse a document on the DEPT table.
--
--      DEPT is defined in $ORACLE_HOME/rdbms/admin/utlsampl.sql, or can be
--      created with the code below:
--
--        create table dept (
--              deptno number(2) constraint pk_dept primary key,
--              dname varchar2(14),
--              loc varchar2(13)
--        ) ;
--
--        insert into dept values (10,'ACCOUNTING','NEW YORK');
--        insert into dept values (20,'RESEARCH','DALLAS');
--        insert into dept values (30,'SALES','CHICAGO');
--        insert into dept values (40,'OPERATIONS','BOSTON');
--
--      Example Code:
--
--        declare
--             l_depts       sys_refcursor;
--             l_dept_output clob;
--        begin
--            --
--            -- Configure apx_JSON to write to a CLOB instead of SYS.HTP.
--            --
--            apx_JSON.initialize_clob_output;
--            --
--            -- Open a ref cursor for departments 10 and 20.
--            --
--            open l_depts for
--                select *
--                  from dept
--                 where deptno in (10, 20);
--            --
--            -- Write the cursor's records.
--            --
--            apx_JSON.write(l_depts);
--            --
--            -- Get the CLOB and free apx_JSON's internal buffer.
--            --
--            l_dept_output := apx_JSON.get_clob_output;
--            apx_JSON.free_output;
--            --
--            -- Print the JSON output.
--            --
--            sys.dbms_output.put_line('--- JSON output ---');
--            sys.dbms_output.put_line(l_dept_output);
--            --
--            -- Parse the JSON output, to later access individual attributes.
--            --
--            apx_JSON.parse(l_dept_output);
--            --
--            -- Print all departments.
--            --
--            sys.dbms_output.put_line('--- Departments ---');
--            for i in 1 .. apx_JSON.get_count('.') loop
--                sys.dbms_output.put_line (
--                    'DEPTNO=' ||apx_JSON.get_number('[%d].DEPTNO', i)||
--                    ', DNAME='||apx_JSON.get_varchar2('[%d].DNAME', i)||
--                    ', LOC='  ||apx_JSON.get_varchar2('[%d].LOC', i) );
--            end loop;
--        end;
--
--      Output:
--
--        --- JSON output ---
--        [
--        {
--        "DEPTNO":10
--        ,"DNAME":"ACCOUNTING"
--        ,"LOC":"NEW YORK"
--        }
--        ,{
--        "DEPTNO":20
--        ,"DNAME":"RESEARCH"
--        ,"LOC":"DALLAS"
--        }
--        ]
--
--        --- Departments ---
--        DEPTNO=10, DNAME=ACCOUNTING, LOC=NEW YORK
--        DEPTNO=20, DNAME=RESEARCH, LOC=DALLAS
--
--    EXAMPLE 5
--      Generate and parse a document on the DEPT and EMP tables.
--
--      The tables are defined in $ORACLE_HOME/rdbms/admin/utlsampl.sql, or can
--      be created with the code below:
--
--        create table dept
--               (deptno number(2) constraint pk_dept primary key,
--                dname varchar2(14) ,
--                loc varchar2(13) ) ;
--        create table emp
--               (empno number(4) constraint pk_emp primary key,
--                ename varchar2(10),
--                job varchar2(9),
--                mgr number(4),
--                hiredate date,
--                sal number(7,2),
--                comm number(7,2),
--                deptno number(2) constraint fk_deptno references dept);
--        insert into dept values (10,'ACCOUNTING','NEW YORK');
--        insert into dept values (20,'RESEARCH','DALLAS');
--        insert into dept values (30,'SALES','CHICAGO');
--        insert into dept values (40,'OPERATIONS','BOSTON');
--        insert into emp values (7369,'SMITH','CLERK',7902,to_date('17-12-1980','dd-mm-yyyy'),800,null,20);
--        insert into emp values (7499,'ALLEN','SALESMAN',7698,to_date('20-2-1981','dd-mm-yyyy'),1600,300,30);
--        insert into emp values (7521,'WARD','SALESMAN',7698,to_date('22-2-1981','dd-mm-yyyy'),1250,500,30);
--        insert into emp values (7566,'JONES','MANAGER',7839,to_date('2-4-1981','dd-mm-yyyy'),2975,null,20);
--        insert into emp values (7654,'MARTIN','SALESMAN',7698,to_date('28-9-1981','dd-mm-yyyy'),1250,1400,30);
--        insert into emp values (7698,'BLAKE','MANAGER',7839,to_date('1-5-1981','dd-mm-yyyy'),2850,null,30);
--        insert into emp values (7782,'CLARK','MANAGER',7839,to_date('9-6-1981','dd-mm-yyyy'),2450,null,10);
--        insert into emp values (7788,'SCOTT','ANALYST',7566,to_date('13-jul-87','dd-mm-rr')-85,3000,null,20);
--        insert into emp values (7839,'KING','PRESIDENT',NUll,to_date('17-11-1981','dd-mm-yyyy'),5000,null,10);
--        insert into emp values (7844,'TURNER','SALESMAN',7698,to_date('8-9-1981','dd-mm-yyyy'),1500,0,30);
--        insert into emp values (7876,'ADAMS','CLERK',7788,to_date('13-jul-87', 'dd-mm-rr')-51,1100,null,20);
--        insert into emp values (7900,'JAMES','CLERK',7698,to_date('3-12-1981','dd-mm-yyyy'),950,null,30);
--        insert into emp values (7902,'FORD','ANALYST',7566,to_date('3-12-1981','dd-mm-yyyy'),3000,null,20);
--        insert into emp values (7934,'MILLER','CLERK',7782,to_date('23-1-1982','dd-mm-yyyy'),1300,null,10);
--
--      Example Code:
--
--        declare
--             l_depts       sys_refcursor;
--             l_dept_output clob;
--        begin
--            --
--            -- Configure apx_JSON to write to a CLOB instead of SYS.HTP.
--            --
--            apx_JSON.initialize_clob_output;
--            --
--            -- This time, we will not simply emit the ref cursor, but create
--            -- an object with some additional data.
--            --
--            apx_JSON.open_object;
--            --
--            -- Open a ref cursor to select departments 10 and 20. In a nested
--            -- cursor, we also select managers and presidents of the
--            -- departments.
--            --
--            open l_depts for
--                select dept.*,
--                       cursor (
--                           select ename, job
--                             from emp
--                            where emp.deptno = dept.deptno
--                              and emp.job    in ('MANAGER', 'PRESIDENT')) "VIPs"
--                  from dept
--                 where deptno in (10, 20);
--            --
--            -- Write the cursor's records as object attribute "items".
--            --
--            apx_JSON.write('items', l_depts);
--            --
--            -- Write additional data.
--            --
--            apx_JSON.write('created', sysdate);
--            --
--            -- Close the top level object.
--            --
--            apx_JSON.close_object;
--            --
--            -- Get the CLOB and free apx_JSON's internal buffer.
--            --
--            l_dept_output := apx_JSON.get_clob_output;
--            apx_JSON.free_output;
--            --
--            -- Print the JSON output.
--            --
--            sys.dbms_output.put_line('--- JSON output ---');
--            sys.dbms_output.put_line(l_dept_output);
--            --
--            -- Parse the JSON output, to later access individual attributes.
--            --
--            apx_JSON.parse(l_dept_output);
--            --
--            -- Print all departments.
--            --
--            sys.dbms_output.put_line('--- Departments ---');
--            for i in 1 .. apx_JSON.get_count('items') loop
--                sys.dbms_output.put_line (
--                    'DEPTNO=' ||apx_JSON.get_number('items[%d].DEPTNO', i)||
--                    ', DNAME='||apx_JSON.get_varchar2('items[%d].DNAME', i)||
--                    ', LOC='  ||apx_JSON.get_varchar2('items[%d].LOC', i) );
--                for j in 1 .. apx_JSON.get_count('items[%d].VIPs', i) loop
--                    sys.dbms_output.put_line (
--                        '- '||apx_JSON.get_varchar2('items[%d].VIPs[%d].JOB', i, j)||
--                        ' '||apx_JSON.get_varchar2('items[%d].VIPs[%d].ENAME', i, j) );
--                end loop;
--            end loop;
--            --
--            -- Print metadata.
--            --
--            sys.dbms_output.put_line (
--                '--- Created: '||
--                to_char(apx_JSON.get_date('created'), 'yyyy/mm/dd')||
--                ' ---' );
--        end;
--
--      Output (JSON was formatted for better reading):
--
--        --- JSON output ---
--        {
--            "items": [
--                {
--                    "DEPTNO": 10,
--                    "DNAME": "ACCOUNTING",
--                    "LOC": "NEW YORK",
--                    "VIPs": [
--                        {
--                            "ENAME": "CLARK",
--                            "JOB": "MANAGER"
--                        },
--                        {
--                            "ENAME": "KING",
--                            "JOB": "PRESIDENT"
--                        }
--                    ]
--                },
--                {
--                    "DEPTNO": 20,
--                    "DNAME": "RESEARCH",
--                    "LOC": "DALLAS",
--                    "VIPs": [
--                        {
--                            "ENAME": "JONES",
--                            "JOB": "MANAGER"
--                        }
--                    ]
--                }
--            ],
--            "created": "2017-08-18T13:10:23Z"
--        }
--        --- Departments ---
--        DEPTNO=10, DNAME=ACCOUNTING, LOC=NEW YORK
--        - MANAGER CLARK
--        - PRESIDENT KING
--        DEPTNO=20, DNAME=RESEARCH, LOC=DALLAS
--        - MANAGER JONES
--        --- Created: 2017/08/18 ---
--
--    MODIFIED   (MM/DD/YYYY)
--    cneumuel    02/18/2013 - Created
--    cneumuel    03/11/2013 - In bool, num, str: added p[0-4]
--    cneumuel    03/12/2013 - Renamed bool, num, str to get_boolean, get_number, get_varchar2
--                           - added c_object, c_array, get_count
--    cneumuel    03/18/2013 - Added get_value
--    cneumuel    04/26/2013 - Renamed vc4000array to apx_t_varchar2
--    cneumuel    05/16/2013 - Added get_members
--    cneumuel    05/17/2013 - In parse: added p_strict
--    cneumuel    05/27/2013 - Added writer procedures (feature #1195)
--    cneumuel    05/28/2013 - Added does_exist, find_paths_like
--                           - In get%: added p_default
--    cneumuel    08/27/2013 - Moved write procedures to apx_t_json_generator (feature #1195)
--    cneumuel    12/03/2013 - pN parameters are varchar2 instead of pls_integer, g_values default
--    cneumuel    01/13/2014 - Added get_xml_to_json
--                           - Added parse() for xmltype
--    cneumuel    01/27/2014 - Made xmltype parse() procedures to_xmltype() functions
--    cneumuel    02/04/2014 - Integrated output interface and removed apx_t_json_generator (feature #1195)
--    cneumuel    02/06/2014 - Moved t_output and g_output to package body
--    cneumuel    02/20/2014 - In write(sys_refcursor): remove p_lower_names because of inconsistencies if an implicit xmltype conversion is needed
--    cneumuel    04/24/2014 - Moved apx_json.escape to apx_escape.json and improved performance
--    cneumuel    04/29/2014 - Documentation
--    cneumuel    05/05/2014 - Documentation. Removed p_key_column from sys_refcursor write procedures.
--    cneumuel    07/07/2014 - Made write_raw() public
--    cneumuel    07/18/2014 - In write(p_name, ...): add p_write_null
--    cneumuel    09/19/2014 - Added links, write_links and write_items to support oracle rest service standard json, for mike and kris
--    cneumuel    09/26/2014 - In link: added p_templated, p_method, p_profile
--    cneumuel    10/23/2014 - Added initialize_clob_output, get_clob_output, free_output
--    cneumuel    11/10/2014 - In get_%: move p_values parameter to the end of the argument list
--    cneumuel    11/21/2014 - Added overloaded parse and to_xmltype for apx_global.vc_arr2 (bug #20077254)
--    cneumuel    12/05/2014 - In write_items: default p_item_links and p_links to null
--    cneumuel    12/10/2014 - In initalize_output: add p_http_cache_etag
--    cneumuel    06/23/2015 - In write(<sys_refcursor>),write(<xmltype>),write(p_name,<sys_refcursor>),write(p_name,<xmltype>): added documentation (bug #21303648)
--    pawolf      11/03/2015 - Added write for apx_t_varchar2 and apx_t_number (feature #1881)
--    pawolf      02/10/2016 - Added examples to write procedures of apx_t_varchar2 and apx_t_number
--    pawolf      07/28/2016 - Added new apis for timestamp handling
--    cneumuel    09/21/2016 - Added parsing support for clob attributes (bug #21266549)
--    cneumuel    08/18/2017 - Added package examples 4 and 5.
--    pawolf      10/30/2017 - Added write_raw which support more than 32KB (bug #26199331)
--    cneumuel    11/07/2017 - Added to_member_name (feature #2240)
--    cneumuel    11/27/2017 - Added get_t_varchar2, get_t_number (feature #2208)
--    cczarski    01/17/2018 - Added get_xmltype_sql functions
--    cczarski    02/08/2018 - added time zone support to stringify, date_get and get_timestamp* functions
--
--------------------------------------------------------------------------------

--##############################################################################
--#
--# PARSER INTERFACE
--#
--##############################################################################

--==============================================================================
subtype t_kind is binary_integer range 1 .. 8;
c_null     constant t_kind := 1;
c_true     constant t_kind := 2;
c_false    constant t_kind := 3;
c_number   constant t_kind := 4;
c_varchar2 constant t_kind := 5;
c_object   constant t_kind := 6;
c_array    constant t_kind := 7;
c_clob     constant t_kind := 8;

--==============================================================================
-- JSON data is stored in an index by varchar2 table. The JSON values are
-- stored as records. The discriminator "kind" determines whether the value
-- is null, true, false, a number, a varchar2, a clob, an object or an array. It
-- depends on "kind" which record fields are used and how. If not explicitly
-- mentioned below, the other record fields' values are undefined:
--
-- * c_null:     -
-- * c_true:     -
-- * c_false:    -
-- * c_number:   number_value contains the number value
-- * c_varchar2: varchar2_value contains the varchar2 value
-- * c_clob:     clob_value contains the clob
-- * c_object:   object_members contains the names of the object's members
-- * c_array:    number_value contains the array length
--==============================================================================
type t_value is record (
    kind           t_kind,
    number_value   number,
    varchar2_value varchar2(32767),
    clob_value     clob,
    object_members apx_t_varchar2 );
type t_values is table of t_value index by varchar2(32767);

--==============================================================================
-- default format for dates and timestamps
--==============================================================================
c_date_iso8601             constant varchar2(30) := 'yyyy-mm-dd"T"hh24:mi:ss"Z"';

c_timestamp_iso8601        constant varchar2(30) := 'yyyy-mm-dd"T"hh24:mi:ss"Z"';
c_timestamp_iso8601_tzd    constant varchar2(35) := 'yyyy-mm-dd"T"hh24:mi:sstzh:tzm';
c_timestamp_iso8601_tzr    constant varchar2(35) := 'yyyy-mm-dd"T"hh24:mi:sstzr';

c_timestamp_iso8601_ff     constant varchar2(35) := 'yyyy-mm-dd"T"hh24:mi:ss.ff"Z"';
c_timestamp_iso8601_ff_tzd constant varchar2(35) := 'yyyy-mm-dd"T"hh24:mi:ss.fftzh:tzm';
c_timestamp_iso8601_ff_tzr constant varchar2(35) := 'yyyy-mm-dd"T"hh24:mi:ss.fftzr';

--==============================================================================
-- parse() throws e_parse_error on error
--==============================================================================
e_parse_error     exception;
pragma exception_init(e_parse_error, -20987);

--==============================================================================
-- default JSON values table
--==============================================================================
g_values t_values;

--==============================================================================
-- parse a json-formatted varchar2 and put the members into p_values.
--
-- PARAMETERS
-- * p_values   an index by varchar2 result array which contains the json
--              members and values. defaults to g_values.
-- * p_source json source (varchar2 or clob)
-- * p_strict if true (default), enforce strict JSON rules
--
-- EXAMPLE
--   Parse JSON and print member values.
--
--   declare
--       l_values apx_JSON.t_values;
--   begin
--       apx_JSON.parse (
--           p_values => l_values,
--           p_source => '{ "type": "circle", "coord": [10, 20] }' );
--       sys.htp.p('Point at '||
--                 apx_JSON.get_number (
--                     p_values => l_values,
--                     p_path   => 'coord[1]')||
--                 ','||
--                 apx_JSON.get_number (
--                     p_values => l_values,
--                     p_path   => 'coord[2]'));
--   end;
--==============================================================================
procedure parse (
    p_values   in out nocopy t_values,
    p_source   in varchar2,
    p_strict   in boolean default true );
procedure parse (
    p_values   in out nocopy t_values,
    p_source   in clob,
    p_strict   in boolean default true );
procedure parse (
    p_values   in out nocopy t_values,
    p_source   in vc_arr2,
    p_strict   in boolean default true );

--==============================================================================
-- parse a json-formatted varchar2 and put the members into the package global
-- g_values. this simplified API works similar to the parse() procedures above,
-- but saves the developer from declaring a local variable for parsed JSON data
-- and passing it to each JSON API call.
--
-- PARAMETERS
-- * p_source   json source (varchar2 or clob)
-- * p_strict   if true (default), enforce strict JSON rules
--
-- EXAMPLE
--   Parse JSON and print member values.
--
--   apx_JSON.parse('{ "type": "circle", "coord": [10, 20] }');
--   sys.htp.p('Point at '||
--             apx_JSON.get_number(p_path=>'coord[1]')||
--             ','||
--             apx_JSON.get_number(p_path=>'coord[2]'));
--==============================================================================
procedure parse (
    p_source   in varchar2,
    p_strict   in boolean default true );
procedure parse (
    p_source   in clob,
    p_strict   in boolean default true );
procedure parse (
    p_source   in vc_arr2,
    p_strict   in boolean default true );

--==============================================================================
-- parse a json-formatted varchar2 or clob and convert it to a xmltype
--
-- PARAMETERS
-- * p_source  json source (varchar2 or clob)
-- * p_strict  if true (default), enforce strict JSON rules
--
-- RETURNS
-- * a xmltype representation of the json data
--
-- EXAMPLE
--   Parse JSON and print it's XML representation.
--
--   declare
--       l_xml xmltype;
--   begin
--       l_xml := apx_JSON.to_xmltype('{ "items": [ 1, 2, { "foo": true } ] }');
--       dbms_output.put_line(l_xml.getstringval);
--   end;
--==============================================================================
function to_xmltype (
    p_source   in varchar2,
    p_strict   in boolean default true )
    return sys.xmltype;
function to_xmltype (
    p_source   in clob,
    p_strict   in boolean default true )
    return sys.xmltype;
function to_xmltype (
    p_source   in vc_arr2,
    p_strict   in boolean default true )
    return sys.xmltype;

--==============================================================================
-- parse a json-formatted varchar2 or clob and convert it to a xmltype
--
-- this function overload has the p_strict parameter as VARCHAR2 in order to
-- allow invoking from within a SQL query and having JSON parsing in LAX mode
--
-- PARAMETERS
-- * p_source  json source (varchar2 or clob)
-- * p_strict  if 'Y' (default), enforce strict JSON rules
--
-- RETURNS
-- * a xmltype representation of the json data
--
-- EXAMPLE
--   This SQL query converts JSON to XMLTYPE and uses the XMLTABLE SQL function to extract data.
--   The p_strict argument is set to 'N', so the JSON can successfully be parsed in lax mode, although
--   the "items" attribute is not enquoted.
--
--   select
--        attr_1
--   from
--       xmltable(
--          '/json/items/row'
--          passing apx_JSON.to_xmltype_sql( '{ items: [ 1, 2, { "foo": true } ] }', p_strict => 'N' )
--          columns
--              attr_1 varchar2(20) path 'foo/text()'
--       );
--==============================================================================
function to_xmltype_sql (
    p_source   in varchar2,
    p_strict   in varchar2 default 'Y' )
    return sys.xmltype;
function to_xmltype_sql (
    p_source   in clob,
    p_strict   in varchar2 default 'Y' )
    return sys.xmltype;

--==============================================================================
-- Convert the given string to a JSON member name, usable for accessing values
-- via the get_% functions. Unless member names are simple identifiers (A-Z,
-- 0-9, "_"), they need to be quoted.
--
-- PARAMETERS
-- * p_string           The raw member name.
--
-- RETURNS
-- * A valid member name for get_% functions.
--
-- EXAMPLE
--   Print various converted strings.
--
--     begin
--         sys.dbms_output.put_line('Unquoted: '||apx_JSON.to_member_name('member_name'));
--         sys.dbms_output.put_line('Quoted:   '||apx_JSON.to_member_name('Hello"World'));
--     end;
--
--   Output:
--
--     Unquoted: member_name
--     Quoted:   "Hello\"World"
--==============================================================================
function to_member_name (
    p_string in varchar2 )
    return varchar2;

--==============================================================================
-- Return whether the given path points to an existing value.
--
-- PARAMETERS
-- * p_values           parsed json members. defaults to g_values.
-- * p_path             index into p_values
-- * p[0-4]             each %N in p_path will be replaced by pN and every
--                      i-th %s or %d will be replaced by the p[i-1]
--
-- RETURNS
-- * true/false         whether given path exists in the parsed JSON
--
-- EXAMPLE
--   Parse a JSON string and print whether it contains values under a path.
--
--   declare
--       j apx_JSON.t_values;
--   begin
--       apx_JSON.parse(j, '{ "items": [ 1, 2, { "foo": true } ] }');
--       if apx_JSON.does_exist (
--              p_values => j,
--              p_path   => 'items[%d].foo',
--              p0       => 3 )
--       then
--           dbms_output.put_line('found items[3].foo');
--       end if;
--   end;
--
--==============================================================================
function does_exist (
    p_path             in varchar2,
    p0                 in varchar2 default null,
    p1                 in varchar2 default null,
    p2                 in varchar2 default null,
    p3                 in varchar2 default null,
    p4                 in varchar2 default null,
    p_values           in t_values default g_values )
    return boolean;

--==============================================================================
-- return boolean member value at a given path
--
-- PARAMETERS
-- * p_values           parsed json members. defaults to g_values.
-- * p_path             index into p_values
-- * p[0-4]             each %N in p_path will be replaced by pN and every
--                      i-th %s or %d will be replaced by the p[i-1]
-- * p_default          default value if the member does not exist
--
-- RETURNS
-- * null/true/false    value at the given path position
--
-- RAISES
-- * VALUE_ERROR        if p_values(p_path) is not a boolean
--
-- EXAMPLE
--   Parse a JSON string and print the value at a position.
--
--   declare
--       j apx_JSON.t_values;
--   begin
--       apx_JSON.parse(j, '{ "items": [ 1, 2, { "foo": true } ] }');
--       if apx_JSON.get_boolean (
--              p_values => j,
--              p_path   => 'items[%d].foo',
--              p0       => 3 )
--       then
--           dbms_output.put_line('items[3].foo is true');
--       end if;
--   end;
--==============================================================================
function get_boolean (
    p_path             in varchar2,
    p0                 in varchar2 default null,
    p1                 in varchar2 default null,
    p2                 in varchar2 default null,
    p3                 in varchar2 default null,
    p4                 in varchar2 default null,
    p_default          in boolean  default null,
    p_values           in t_values default g_values )
    return boolean;

--==============================================================================
-- return numeric member value
--
-- PARAMETERS
-- * p_values           parsed json members. defaults to g_values.
-- * p_path             index into p_values
-- * p[0-4]             each %N in p_path will be replaced by pN and every
--                      i-th %s or %d will be replaced by the p[i-1]
-- * p_default          default value if the member does not exist
--
-- RETURNS
-- * a number           value at the given path position
--
-- RAISES
-- * VALUE_ERROR        if p_values(p_path) is not a number
--
-- EXAMPLE
--   Parse a JSON string and print the value at a position.
--
--   declare
--       j apx_JSON.t_values;
--   begin
--       apx_JSON.parse(j, '{ "items": [ 1, 2, { "foo": 42 } ] }');
--       dbms_output.put_line(apx_JSON.get_number (
--                                p_values => j,
--                                p_path   => 'items[%d].foo',
--                                p0       => 3));
--   end;
--==============================================================================
function get_number (
    p_path             in varchar2,
    p0                 in varchar2 default null,
    p1                 in varchar2 default null,
    p2                 in varchar2 default null,
    p3                 in varchar2 default null,
    p4                 in varchar2 default null,
    p_default          in number   default null,
    p_values           in t_values default g_values )
    return number;

--==============================================================================
-- return varchar2 member value. this function auto-converts boolean and number
-- values.
--
-- PARAMETERS
-- * p_values           parsed json members. defaults to g_values.
-- * p_path             index into p_values
-- * p[0-4]             each %N in p_path will be replaced by pN and every
--                      i-th %s or %d will be replaced by the p[i-1]
-- * p_default          default value if the member does not exist
--
-- RETURNS
-- * a varchar2         value at the given path position
--
-- RAISES
-- * VALUE_ERROR        if p_values(p_path) is an array or an object
--
-- EXAMPLE
--   Parse a JSON string and print the value at a position.
--
--   declare
--       j apx_JSON.t_values;
--   begin
--       apx_JSON.parse(j, '{ "items": [ 1, 2, { "foo": 42 } ] }');
--       dbms_output.put_line(apx_JSON.get_varchar2 (
--                                p_values => j,
--                                p_path   => 'items[%d].foo',
--                                p0       => 3));
--   end;
--==============================================================================
function get_varchar2 (
    p_path             in varchar2,
    p0                 in varchar2 default null,
    p1                 in varchar2 default null,
    p2                 in varchar2 default null,
    p3                 in varchar2 default null,
    p4                 in varchar2 default null,
    p_default          in varchar2 default null,
    p_values           in t_values default g_values )
    return varchar2;

--==============================================================================
-- return clob member value. this function auto-converts varchar2, boolean and
-- number values.
--
-- PARAMETERS
-- * p_values           parsed json members. defaults to g_values.
-- * p_path             index into p_values
-- * p[0-4]             each %N in p_path will be replaced by pN and every
--                      i-th %s or %d will be replaced by the p[i-1]
-- * p_default          default value if the member does not exist
--
-- RETURNS
-- * a clob             value at the given path position
--
-- RAISES
-- * VALUE_ERROR        if p_values(p_path) is an array or an object
--
-- EXAMPLE
--   Parse a JSON string and print the value at a position.
--
--   declare
--       j apx_JSON.t_values;
--   begin
--       apx_JSON.parse(j, '{ "items": [ 1, 2, { "foo": 42 } ] }');
--       dbms_output.put_line(apx_JSON.get_clob (
--                                p_values => j,
--                                p_path   => 'items[%d].foo',
--                                p0       => 3));
--   end;
--==============================================================================
function get_clob (
    p_path             in varchar2,
    p0                 in varchar2 default null,
    p1                 in varchar2 default null,
    p2                 in varchar2 default null,
    p3                 in varchar2 default null,
    p4                 in varchar2 default null,
    p_default          in clob     default null,
    p_values           in t_values default g_values )
    return clob;

--==============================================================================
-- return date member value.
--
-- PARAMETERS
-- * p_values           parsed json members. defaults to g_values.
-- * p_path             index into p_values
-- * p[0-4]             each %N in p_path will be replaced by pN and every
--                      i-th %s or %d will be replaced by the p[i-1]
-- * p_default          default value if the member does not exist
-- * p_format           date format mask
-- * p_at_time_zone     when NULL (default), then all time zone information is ignored,
--                      otherwise return date value converted to given time zone.
--
-- RETURNS
-- * a date             value at the given path position
--
-- RAISES
-- * VALUE_ERROR        if p_values(p_path) is not a date
--
-- EXAMPLE
--   Parse a JSON string and print the value at a position.
--
--   declare
--       j apx_JSON.t_values;
--   begin
--       apx_JSON.parse(j, '{ "items": [ 1, 2, { "foo": "2014-04-29T10:08:00Z" } ] }');
--       dbms_output.put_line(to_char(apx_JSON.get_date (
--                                        p_values => j,
--                                        p_path   => 'items[%d].foo',
--                                        p0       => 3),
--                                    'DD-Mon-YYYY'));
--   end;
--==============================================================================
function get_date (
    p_path             in varchar2,
    p0                 in varchar2 default null,
    p1                 in varchar2 default null,
    p2                 in varchar2 default null,
    p3                 in varchar2 default null,
    p4                 in varchar2 default null,
    p_default          in date     default null,
    p_format           in varchar2 default null,
    p_values           in t_values default g_values,
    p_at_time_zone     in varchar2 default null )
   return date;

--==============================================================================
-- return timestamp member value.
--
-- PARAMETERS
-- * p_values           parsed json members. defaults to g_values.
-- * p_path             index into p_values
-- * p[0-4]             each %N in p_path will be replaced by pN and every
--                      i-th %s or %d will be replaced by the p[i-1]
-- * p_default          default value if the member does not exist
-- * p_format           timestamp format mask
-- * p_at_time_zone     when NULL (default), then all time zone information is ignored,
--                      otherwise return date value converted to given time zone.
--
-- RETURNS
-- * a date             value at the given path position
--
-- RAISES
-- * VALUE_ERROR        if p_values(p_path) is not a timestamp
--
-- EXAMPLE
--   Parse a JSON string and print the value at a position.
--
--   declare
--       j apx_JSON.t_values;
--   begin
--       apx_JSON.parse(j, '{ "items": [ 1, 2, { "foo": "2014-04-29T10:08:00.345Z" } ] }');
--       dbms_output.put_line(to_char(apx_JSON.get_timestamp (
--                                        p_values => j,
--                                        p_path   => 'items[%d].foo',
--                                        p0       => 3),
--                                    'DD-Mon-YYYY HH24:MI:SSXFF'));
--   end;
--==============================================================================
function get_timestamp (
    p_path             in varchar2,
    p0                 in varchar2  default null,
    p1                 in varchar2  default null,
    p2                 in varchar2  default null,
    p3                 in varchar2  default null,
    p4                 in varchar2  default null,
    p_default          in timestamp default null,
    p_format           in varchar2  default null,
    p_values           in t_values  default g_values,
    p_at_time_zone     in varchar2  default null )
    return timestamp;

--==============================================================================
-- return timestamp with local time zone member value.
--
-- PARAMETERS
-- * p_values           parsed json members. defaults to g_values.
-- * p_path             index into p_values
-- * p[0-4]             each %N in p_path will be replaced by pN and every
--                      i-th %s or %d will be replaced by the p[i-1]
-- * p_default          default value if the member does not exist
-- * p_format           timestamp with time zone format mask
-- * p_at_time_zone     when NULL (default), then all time zone information is ignored.
--                      Otherwise return the date value converted to time zone provided.
--
-- RETURNS
-- * a date             value at the given path position
--
-- RAISES
-- * VALUE_ERROR        if p_values(p_path) is not a timestamp
--
-- EXAMPLE
--   Parse a JSON string and print the value at a position.
--
--   declare
--       j apx_JSON.t_values;
--   begin
--       apx_JSON.parse(j, '{ "items": [ 1, 2, { "foo": "2014-04-29T10:08:00.345 02:00" } ] }');
--       dbms_output.put_line(to_char(apx_JSON.get_timestamp_ltz (
--                                        p_values => j,
--                                        p_path   => 'items[%d].foo',
--                                        p0       => 3),
--                                    'DD-Mon-YYYY HH24:MI:SSXFF'));
--   end;
--==============================================================================
function get_timestamp_ltz (
    p_path             in varchar2,
    p0                 in varchar2  default null,
    p1                 in varchar2  default null,
    p2                 in varchar2  default null,
    p3                 in varchar2  default null,
    p4                 in varchar2  default null,
    p_default          in timestamp with local time zone default null,
    p_format           in varchar2  default c_timestamp_iso8601_ff_tzr,
    p_values           in t_values  default g_values )
    return timestamp with local time zone;

--==============================================================================
-- return timestamp with time zone member value.
--
-- PARAMETERS
-- * p_values           parsed json members. defaults to g_values.
-- * p_path             index into p_values
-- * p[0-4]             each %N in p_path will be replaced by pN and every
--                      i-th %s or %d will be replaced by the p[i-1]
-- * p_default          default value if the member does not exist
-- * p_format           timestamp with time zone format mask
--
-- RETURNS
-- * a date             value at the given path position
--
-- RAISES
-- * VALUE_ERROR        if p_values(p_path) is not a timestamp
--
-- EXAMPLE
--   Parse a JSON string and print the value at a position.
--
--   declare
--       j apx_JSON.t_values;
--   begin
--       apx_JSON.parse(j, '{ "items": [ 1, 2, { "foo": "2014-04-29T10:08:00.345 02:00" } ] }');
--       dbms_output.put_line(to_char(apx_JSON.get_timestamp_tz (
--                                        p_values => j,
--                                        p_path   => 'items[%d].foo',
--                                        p0       => 3),
--                                    'DD-Mon-YYYY HH24:MI:SSXFF TZH:TZM'));
--   end;
--==============================================================================
function get_timestamp_tz (
    p_path             in varchar2,
    p0                 in varchar2  default null,
    p1                 in varchar2  default null,
    p2                 in varchar2  default null,
    p3                 in varchar2  default null,
    p4                 in varchar2  default null,
    p_default          in timestamp with time zone default null,
    p_format           in varchar2  default c_timestamp_iso8601_ff_tzr,
    p_values           in t_values  default g_values )
    return timestamp with time zone;

--==============================================================================
-- return the number of array elements or object members
--
-- PARAMETERS
-- * p_values           parsed json members. defaults to g_values.
-- * p_path             index into p_values
-- * p[0-4]             each %N in p_path will be replaced by pN and every
--                      i-th %s or %d will be replaced by the p[i-1]
--
-- RETURNS
-- * number of array elements or object members or null if the array/object
--   could not be found
--
-- RAISES
-- * VALUE_ERROR        if p_values(p_path) is not an array or an object
--
-- EXAMPLE
--   Parse a JSON string and print the number of members at positions.
--
--   declare
--       j apx_JSON.t_values;
--   begin
--       apx_JSON.parse(j, '{ "foo": 3, "bar": [1, 2, 3, 4] }');
--       dbms_output.put_line(apx_JSON.get_count (
--                                p_values => j,
--                                p_path   => '.'));   -- 2 (foo and bar)
--       dbms_output.put_line(apx_JSON.get_count (
--                                p_values => j,
--                                p_path   => 'bar')); -- 4
--   end;
--==============================================================================
function get_count (
    p_path             in varchar2,
    p0                 in varchar2 default null,
    p1                 in varchar2 default null,
    p2                 in varchar2 default null,
    p3                 in varchar2 default null,
    p4                 in varchar2 default null,
    p_values           in t_values default g_values )
    return number;

--==============================================================================
-- return the table of object_member names for an object
--
-- PARAMETERS
-- * p_values           parsed json members. defaults to g_values.
-- * p_path             index into p_values
-- * p[0-4]             each %N in p_path will be replaced by pN and every
--                      i-th %s or %d will be replaced by the p[i-1]
--
-- RETURNS
-- * object_members of the object or null if the object could not be found
--
-- RAISES
-- * VALUE_ERROR        if p_values(p_path) is not an array or an object
--
-- EXAMPLE
--   Parse a JSON string and print members at positions.
--
--   declare
--       j apx_JSON.t_values;
--   begin
--       apx_JSON.parse(j, '{ "foo": 3, "bar": [1, 2, 3, 4] }');
--       dbms_output.put_line(apx_JSON.get_members (
--                                p_values => j,
--                                p_path   => '.')(1)); -- foo
--       dbms_output.put_line(apx_JSON.get_members (
--                                p_values => j,
--                                p_path   => '.')(2)); -- bar
--   end;
--==============================================================================
function get_members (
    p_path             in varchar2,
    p0                 in varchar2 default null,
    p1                 in varchar2 default null,
    p2                 in varchar2 default null,
    p3                 in varchar2 default null,
    p4                 in varchar2 default null,
    p_values           in t_values default g_values )
    return apx_t_varchar2;

--==============================================================================
-- Return the varchar2 attributes of an array.
--
-- PARAMETERS
-- * p_values:          Parsed json members. defaults to g_values.
-- * p_path:            Index into p_values.
-- * p[0-4]:            Each %N in p_path will be replaced by pN and every
--                      i-th %s or %d will be replaced by the p[i-1].
--
-- RETURNS
-- * Array member values if the referenced t_value is an array.
-- * An array with just the referenced value if it's type can be converted to a
--   varchar2.
--
-- RAISES
-- * VALUE_ERROR        On conversion errors.
--
-- EXAMPLE
--   Parse a JSON string and print the value at position 1.
--
--     declare
--         j          apx_JSON.t_values;
--         l_elements apex_t_varchar2;
--     begin
--         apx_JSON.parse(j, '{ "foo": ["one", "two"], "bar": "three" }');
--         l_elements := apx_JSON.get_t_varchar2 (
--                           p_values => j,
--                           p_path   => 'foo' );
--         for i in 1 .. l_elements.count loop
--             sys.dbms_output.put_line(i||':'||l_elements(i));
--         end loop;
--         l_elements := apx_JSON.get_t_varchar2 (
--                           p_values => j,
--                           p_path   => 'bar' );
--         for i in 1 .. l_elements.count loop
--             sys.dbms_output.put_line(i||':'||l_elements(i));
--         end loop;
--     end;
--
--   Output:
--     1:one
--     2:two
--     1:three
--==============================================================================
function get_t_varchar2 (
    p_path             in varchar2,
    p0                 in varchar2 default null,
    p1                 in varchar2 default null,
    p2                 in varchar2 default null,
    p3                 in varchar2 default null,
    p4                 in varchar2 default null,
    p_values           in t_values default g_values )
    return apx_t_varchar2;

--==============================================================================
-- Return the numeric attributes of an array.
--
-- PARAMETERS
-- * p_values:          Parsed json members. defaults to g_values.
-- * p_path:            Index into p_values.
-- * p[0-4]:            Each %N in p_path will be replaced by pN and every
--                      i-th %s or %d will be replaced by the p[i-1].
--
-- RETURNS
-- * Array member values if the referenced t_value is an array.
-- * An array with just the referenced value if it's type can be converted to a
--   number.
--
-- RAISES
-- * VALUE_ERROR        On conversion errors.
--
-- EXAMPLE
--   Parse a JSON string and print the value at position 1.
--
--     declare
--         j          apx_JSON.t_values;
--         l_elements apex_t_number;
--     begin
--         apx_JSON.parse(j, '{ "foo": [111, 222], "bar": 333 }');
--         l_elements := apx_JSON.get_t_number (
--                           p_values => j,
--                           p_path   => 'foo' );
--         for i in 1 .. l_elements.count loop
--             sys.dbms_output.put_line(i||':'||l_elements(i));
--         end loop;
--         l_elements := apx_JSON.get_t_number (
--                           p_values => j,
--                           p_path   => 'bar' );
--         for i in 1 .. l_elements.count loop
--             sys.dbms_output.put_line(i||':'||l_elements(i));
--         end loop;
--     end;
--
--   Output:
--     1:111
--     2:222
--     1:333
--==============================================================================
function get_t_number (
    p_path             in varchar2,
    p0                 in varchar2 default null,
    p1                 in varchar2 default null,
    p2                 in varchar2 default null,
    p3                 in varchar2 default null,
    p4                 in varchar2 default null,
    p_values           in t_values default g_values )
    return apx_t_number;

--==============================================================================
-- return the t_value at a path position
--
-- PARAMETERS
-- * p_values           parsed json members. defaults to g_values.
-- * p_path             index into p_values
-- * p[0-4]             each %N in p_path will be replaced by pN and every
--                      i-th %s or %d will be replaced by the p[i-1]
--
-- RETURNS
-- * t_value            the t_value at the given path position. the record
--                      attributes will be null if no data was found.
--
-- EXAMPLE
--   Parse a JSON string and print attributes of values at positions.
--
--   declare
--       j apx_JSON.t_values;
--       v apx_JSON.t_value;
--   begin
--       apx_JSON.parse(j, '{ "foo": 3, "bar": [1, 2, 3, 4] }');
--       v := apx_JSON.get_value (
--                p_values => j,
--                p_path   => 'bar[%d]',
--                p0       => 2); -- returns the t_value for bar[2]
--       dbms_output.put_line(v.number_value);      -- 2
--       v := apx_JSON.get_value (
--                p_values => j,
--                p_path   => 'does.not.exist');
--       dbms_output.put_line(case when v.kind is null then 'not found!' end);
--   end;
--==============================================================================
function get_value (
    p_path             in varchar2,
    p0                 in varchar2 default null,
    p1                 in varchar2 default null,
    p2                 in varchar2 default null,
    p3                 in varchar2 default null,
    p4                 in varchar2 default null,
    p_values           in t_values default g_values )
    return t_value;

--==============================================================================
-- Return paths into p_values that match a pattern
--
-- PARAMETERS
-- * p_values           parsed json members. defaults to g_values.
-- * p_return_path      search pattern for the return path
-- * p_subpath          search pattern under p_return_path (optional)
-- * p_value            search pattern for value (optional)
--
-- RETURNS
-- * apex_t_varchar2    table of paths that match the pattern
--
-- EXAMPLE
--   Parse a JSON string, find paths that match a pattern and print the values
--   under the paths.
--
--   declare
--       j       apx_JSON.t_values;
--       l_paths apex_t_varchar2;
--   begin
--       apx_JSON.parse(j, '{ "items": [ { "name": "Amulet of Yendor", "magical": true }, '||
--                          '             { "name": "smelly slippers",  "magical": "rather not" } ]}');
--       l_paths := apx_JSON.find_paths_like (
--                      p_values      => j,
--                      p_return_path => 'items[%]',
--                      p_subpath     => '.magical',
--                      p_value       => 'true' );
--       dbms_output.put_line('Magical items:');
--       for i in 1 .. l_paths.count loop
--           dbms_output.put_line(apx_JSON.get_varchar2(j, l_paths(i)||'.name'));
--       end loop;
--   end;
--==============================================================================
function find_paths_like (
    p_return_path      in varchar2,
    p_subpath          in varchar2 default null,
    p_value            in varchar2 default null,
    p_values           in t_values default g_values )
    return apx_t_varchar2;

--##############################################################################
--#
--# CONVERSION UTILITIES
--#
--##############################################################################

--==============================================================================
-- convert p_value to an escaped JSON value
--
-- EXAMPLE
--   Query that returns the JSON varchar2 value "line 1\nline 2"
--
--   select apx_JSON.stringify('line 1'||chr(10)||'line 2') from dual
--==============================================================================
function stringify (
    p_value in varchar2 )
    return varchar2;

--==============================================================================
-- convert p_value to an escaped JSON value
--
-- EXAMPLE
--   Query that returns a JSON number value.
--
--   select apx_JSON.stringify(-1/10) from dual
--==============================================================================
function stringify (
    p_value in number )
    return varchar2;

--==============================================================================
-- convert p_value to an escaped JSON value
--
-- EXAMPLE
--   Query that returns a JSON varchar2 value that is suitable to be converted
--   to dates.
--
--   select apx_JSON.stringify(sysdate) from dual
--==============================================================================
function stringify (
    p_value          in date,
    p_format         in varchar2 default c_date_iso8601,
    p_from_time_zone in varchar2 default null )
    return varchar2;

--==============================================================================
-- convert p_value to an escaped JSON value
--
-- EXAMPLE
--   Query that returns a JSON varchar2 value that is suitable to be converted
--   to timestamp.
--
--   select apx_JSON.stringify(localtimestamp) from dual
--==============================================================================
function stringify (
    p_value          in timestamp,
    p_format         in varchar2 default c_timestamp_iso8601_ff,
    p_from_time_zone in varchar2 default null )
    return varchar2;

--==============================================================================
-- convert p_value to an escaped JSON value
--
-- EXAMPLE
--   Query that returns a JSON varchar2 value that is suitable to be converted
--   to timestamp.
--
--   select apx_JSON.stringify(current_timestamp) from dual
--==============================================================================
function stringify (
    p_value        in timestamp with local time zone,
    p_format       in varchar2                       default c_timestamp_iso8601_ff_tzr,
    p_at_time_zone in varchar2                       default null )
    return varchar2;

--==============================================================================
-- convert p_value to an escaped JSON value
--
-- EXAMPLE
--   Query that returns a JSON varchar2 value that is suitable to be converted
--   to timestamp.
--
--   select apx_JSON.stringify(current_timestamp) from dual
--==============================================================================
function stringify (
    p_value  in timestamp with time zone,
    p_format in varchar2    default c_timestamp_iso8601_ff_tzd )
    return varchar2;

--==============================================================================
-- convert p_value to an escaped JSON value
--
-- EXAMPLE
--   Print JSON boolean values
--
--   begin
--     sys.htp.p(apx_JSON.stringify(true));
--     sys.htp.p(apx_JSON.stringify(false));
--   end;
--==============================================================================
function stringify (
    p_value in boolean )
    return varchar2;

--##############################################################################
--#
--# OUTPUT INTERFACE
--#
--##############################################################################

--==============================================================================
-- initialize the output interface for the SYS.HTP buffer. you only have to
-- call this procedure if you want to modify the parameters below. initially,
-- output is already configured with the defaults mentioned below.
--
-- PARAMETERS
--   * p_http_header     If true (the default), write an "application/json" mime
--                       type header
--   * p_http_cache      This parameter is only relevant if p_write_header is true.
--                       If true, writes a Cache-Control header that allows
--                       caching of the JSON content.
--                       If false (default), writes Cache-Control: no-cache
--                       Otherwise, does not write Cache-Control
--   * p_http_cache_etag If not null, writes an etag header. This parameter
--                       is only used if p_http_cache is true.
--   * p_indent          Indent level. Defaults to 2 if debug is turned on, 0
--                       otherwise.
--
-- SEE ALSO
--   initialize_clob_output
--
-- EXAMPLE
--   configure apx_JSON to not emit default headers, because we write them
--   directly
--
--   begin
--     apx_JSON.initialize_output (
--         p_http_header => false );
--
--     sys.owa_util.mime_header('application/json', false);
--     sys.owa_util.status_line(429, 'Too Many Requests');
--     sys.owa_util.http_header_close;
--     --
--     apx_JSON.open_object;
--     apx_JSON.write('maxRequestsPerSecond', 10);
--     apx_JSON.close_object;
--   end;
--==============================================================================
procedure initialize_output (
    p_http_header     in boolean     default true,
    p_http_cache      in boolean     default false,
    p_http_cache_etag in varchar2    default null,
    p_indent          in pls_integer default null );

--==============================================================================
-- initialize the output interface to write to a temporary CLOB. the default is
-- to write to SYS.HTP. if using CLOB output, you should call free_output() at
-- the end. to free the CLOB.
--
-- SEE ALSO
--   initialize_output, get_clob_output, free_output
--
-- PARAMETERS
--   * p_dur          duration of the temporary CLOB. this can be
--                    DBMS_LOB.SESSION or DBMS_LOB.CALL (the default).
--   * p_cache        specifies if the lob should be read into buffer cache or
--                    not.
--   * p_indent       Indent level. Defaults to 2 if debug is turned on, 0
--                    otherwise.
--
-- EXAMPLE
--   In this example, we configure apx_JSON for CLOB output, generate JSON,
--   print the CLOB with DBMS_OUTPUT and finally free the CLOB.
--
--   begin
--     apx_JSON.initialize_clob_output;
--
--     apx_JSON.open_object;
--     apx_JSON.write('hello', 'world');
--     apx_JSON.close_object;
--
--     dbms_output.put_line(apx_JSON.get_clob_output);
--
--     apx_JSON.free_output;
--   end;
--   /
--==============================================================================
procedure initialize_clob_output (
    p_dur         in pls_integer default sys.dbms_lob.call,
    p_cache       in boolean     default true,
    p_indent      in pls_integer default null );

--==============================================================================
-- free output resources. call this procedure after processing, if you are
-- using initialize_clob_output to write to a temporary CLOB.
--
-- SEE ALSO
--   initialize_clob_output, get_clob_output, free_output
--
-- EXAMPLE
--   see initialize_clob_output
--==============================================================================
procedure free_output;

--==============================================================================
-- return the temporary clob that you created with initialize_clob_output.
--
-- SEE ALSO
--   initialize_clob_output, free_output, get_varchar2_output
--
-- EXAMPLE
--   see initialize_clob_output
--==============================================================================
function get_clob_output
    return clob;

--==============================================================================
-- flush pending changes. note that the close procedures below automatically
-- flush.
--
-- EXAMPLE
--   Write incomplete JSON
--
--   begin
--     apx_JSON.open_object;
--     apx_JSON.write('attr', 'value');
--     apx_JSON.flush;
--     sys.htp.p('the "}" is missing');
--   end;
--==============================================================================
procedure flush;

--==============================================================================
-- write {
--
-- PARAMETERS
--   * p_name     If not null, write an object attribute name and colon before the
--                opening brace.
--
-- EXAMPLE
--   Write { "obj": { "obj-attr": "value" }}
--
--   begin
--     apx_JSON.open_object;                -- {
--     apx_JSON.open_object('obj');         --   "obj": {
--     apx_JSON.write('obj-attr', 'value'); --     "obj-attr": "value"
--     apx_JSON.close_all;                  -- }}
--   end;
--==============================================================================
procedure open_object (
    p_name        in varchar2 default null );

--==============================================================================
-- write }
--
-- EXAMPLE
--   Write { "obj-attr": "value" }
--
--   begin
--     apx_JSON.open_object;                -- {
--     apx_JSON.write('obj-attr', 'value'); --   "obj-attr": "value"
--     apx_JSON.close_object;               -- }
--   end;
--==============================================================================
procedure close_object;

--==============================================================================
-- write [
--
-- PARAMETERS
--   * p_name     If not null, write an object attribute name and colon before the
--                opening bracket.
--
-- EXAMPLE
--   write { "array":[ 1 ,[ ] ] }
--
--   begin
--     apx_JSON.open_object;                -- {
--     apx_JSON.open_array('array');        --   "array": [
--     apx_JSON.write(1);                   --     1
--     apx_JSON.open_array;                 --   , [
--     apx_JSON.close_array;                --     ]
--     apx_JSON.close_array;                --   ]
--     apx_JSON.close_object;               -- }
--   end;
--==============================================================================
procedure open_array (
    p_name        in varchar2 default null );

--==============================================================================
-- write ]
--
-- EXAMPLE
--   Write [ 1, 2 ]
--
--   begin
--     apx_JSON.open_array;                 -- [
--     apx_JSON.write(1);                   --   1
--     apx_JSON.write(2);                   -- , 2
--     apx_JSON.close_array;                -- ]
--   end;
--==============================================================================
procedure close_array;

--==============================================================================
-- close all objects and arrays up to the outermost nesting level
--==============================================================================
procedure close_all;

--==============================================================================
-- write array attribute of type varchar2.
--
-- PARAMETERS
--   * p_value    The value to be written
--
-- EXAMPLE
--   Write an array containing 1, "two", "long text", false, the current date
--   and a JSON representation of an xml document.
--
--   declare
--     l_clob clob        := 'long text';
--     l_xml  sys.xmltype := sys.xmltype('<obj><foo>1</foo><bar>2</bar></obj>');
--   begin
--     apx_JSON.open_array;                 -- [
--     apx_JSON.write(1);                   --   1
--     apx_JSON.write('two');               -- , "two"
--     apx_JSON.write(l_clob);              -- , "long text"
--     apx_JSON.write(false);               -- , false
--     apx_JSON.write(sysdate);             -- , "2014-05-05T05:36:08Z"
--     apx_JSON.write(localtimestamp);      -- , "2014-05-05T05:36:08.5434Z"
--     apx_JSON.write(current_timestamp);   -- , "2014-05-05T05:36:08.5434+02:00"
--     apx_JSON.write(l_xml);               -- , { "foo": 1, "bar": 2 }
--     apx_JSON.close_array;                -- ]
--   end;
--==============================================================================
procedure write (
    p_value       in varchar2 );

--==============================================================================
-- write array attribute of type clob.
--
-- PARAMETERS
--   * p_value    The value to be written
--==============================================================================
procedure write (
    p_value       in clob );

--==============================================================================
-- write array attribute
--
-- PARAMETERS
--   * p_value    The value to be written
--==============================================================================
procedure write (
    p_value       in number );

--==============================================================================
-- write array attribute
--
-- PARAMETERS
--   * p_value    The value to be written
--   * p_format   date format mask (default c_date_iso8601)
--==============================================================================
procedure write (
    p_value       in date,
    p_format      in varchar2    default c_date_iso8601 );

--==============================================================================
-- write array attribute
--
-- PARAMETERS
--   * p_value    The value to be written
--   * p_format   date format mask (default c_timestamp_iso8601_ff)
--==============================================================================
procedure write (
    p_value       in timestamp,
    p_format      in varchar2    default c_timestamp_iso8601_ff );

--==============================================================================
-- write array attribute
--
-- PARAMETERS
--   * p_value    The value to be written
--   * p_format   date format mask (default c_timestamp_iso8601_ff_tzd)
--==============================================================================
procedure write (
    p_value       in timestamp with local time zone,
    p_format      in varchar2    default c_timestamp_iso8601_ff_tzr );

--==============================================================================
-- write array attribute
--
-- PARAMETERS
--   * p_value    The value to be written
--   * p_format   date format mask (default c_timestamp_iso8601_ff_tzd)
--==============================================================================
procedure write (
    p_value       in timestamp with time zone,
    p_format      in varchar2    default c_timestamp_iso8601_ff_tzd );

--==============================================================================
-- write array attribute
--
-- PARAMETERS
--   * p_value    The value to be written
--==============================================================================
procedure write (
    p_value       in boolean );

--==============================================================================
-- Write array attribute.
--
-- The procedure uses a XSL transformation to generate JSON. To determine the
-- JSON type of values, it uses the following rules:
-- * If the value is empty, it generates a null value
-- * If upper(value) is TRUE, it generates a boolean true value
-- * If upper(value) is FALSE, it generates a boolean false value
-- * If the XPath number function returns true, it emits the value as is
-- * Otherwise, it enquotes the value (i.e. treats it as a JSON string)
--
-- PARAMETERS
--   * p_value    The value to be written. The XML is converted to JSON.
--==============================================================================
procedure write (
    p_value       in sys.xmltype );

--==============================================================================
-- Write an array with all rows that the cursor returns. each row is a separate
-- object.
--
-- If the query contains object type, collection or cursor columns, the
-- procedure uses write(<xmltype>) to generate JSON. See write(<xmltype>) for
-- further details. Otherwise, it uses DBMS_SQL to fetch rows and the write()
-- procedures for the appropriate column data types for output. If the column
-- type is varchar2 and the uppercase value is 'TRUE' or 'FALSE', it generates
-- boolean values.
--
-- PARAMETERS
--   * p_cursor       The cursor
--
-- EXAMPLE
--   Write an array containing JSON objects for departments 10 and 20.
--
--   declare
--     c sys_refcursor;
--   begin
--     open c for select deptno, dname, loc from dept where deptno in (10, 20);
--     apx_JSON.write(c);
--   end;
--
--   [ { "DEPTNO":10 ,"DNAME":"ACCOUNTING" ,"LOC":"NEW YORK" }
--   , { "DEPTNO":20 ,"DNAME":"RESEARCH" ,"LOC":"DALLAS" } ]
--==============================================================================
procedure write (
    p_cursor      in out nocopy sys_refcursor );

--==============================================================================
-- write an object attribute of type varchar2
--
-- PARAMETERS
--   * p_name         The attribute name
--   * p_value        The attribute value to be written
--   * p_write_null   If true, write null values. If false (the default), do not
--                    write nulls.
--
-- EXAMPLE
--   Write an object containing attributes with values 1, "two", "long text",
--   false, the current date and a JSON representation of an xml document.
--
--   declare
--     l_clob clob        := 'long text';
--     l_xml  sys.xmltype := sys.xmltype('<obj><foo>1</foo><bar>2</bar></obj>');
--     l_null varchar2(10);
--   begin
--     apx_JSON.open_object;                 -- {
--     apx_JSON.write('a1', 1);                   -- "a1": 1
--     apx_JSON.write('a2', 'two');               -- ,"a2": "two"
--     apx_JSON.write('a3', l_clob);              -- ,"a3": "long text"
--     apx_JSON.write('a4', false);               -- ,"a4": false
--     apx_JSON.write('a5', sysdate);             -- ,"a5": "2014-05-05T05:36:08Z"
--     apx_JSON.write('a6', l_xml);               -- ,"a6": { "foo": 1, "bar": 2 }
--     apx_JSON.write('a7', l_null);              --
--     apx_JSON.close_object;                -- }
--   end;
--==============================================================================
procedure write (
    p_name        in varchar2,
    p_value       in varchar2,
    p_write_null  in boolean default false );

--==============================================================================
-- write an object attribute
--
-- PARAMETERS
--   * p_name         The attribute name
--   * p_value        The attribute value to be written
--   * p_write_null   If true, write null values. If false (the default), do not
--                    write nulls.
--==============================================================================
procedure write (
    p_name        in varchar2,
    p_value       in clob,
    p_write_null  in boolean default false );

--==============================================================================
-- write an object attribute
--
-- PARAMETERS
--   * p_name         The attribute name
--   * p_value        The attribute value to be written
--   * p_write_null   If true, write null values. If false (the default), do not
--                    write nulls.
--==============================================================================
procedure write (
    p_name        in varchar2,
    p_value       in number,
    p_write_null  in boolean default false );

--==============================================================================
-- write an object attribute
--
-- PARAMETERS
--   * p_name         The attribute name
--   * p_value        The attribute value to be written
--   * p_format       date format mask (default apx_json.c_date_iso8601)
--   * p_write_null   If true, write null values. If false (the default), do not
--                    write nulls.
--==============================================================================
procedure write (
    p_name        in varchar2,
    p_value       in date,
    p_format      in varchar2    default c_date_iso8601,
    p_write_null  in boolean default false );

--==============================================================================
-- write an object attribute
--
-- PARAMETERS
--   * p_name         The attribute name
--   * p_value        The attribute value to be written
--   * p_format       date format mask (default apx_json.c_timestamp_iso8601_ff)
--   * p_write_null   If true, write null values. If false (the default), do not
--                    write nulls.
--==============================================================================
procedure write (
    p_name        in varchar2,
    p_value       in timestamp,
    p_format      in varchar2    default c_timestamp_iso8601_ff,
    p_write_null  in boolean default false );

--==============================================================================
-- write an object attribute
--
-- PARAMETERS
--   * p_name         The attribute name
--   * p_value        The attribute value to be written
--   * p_format       date format mask (default apx_json.c_timestamp_iso8601_ff_tzd)
--   * p_write_null   If true, write null values. If false (the default), do not
--                    write nulls.
--==============================================================================
procedure write (
    p_name        in varchar2,
    p_value       in timestamp with local time zone,
    p_format      in varchar2    default c_timestamp_iso8601_ff_tzr,
    p_write_null  in boolean default false );

--==============================================================================
-- write an object attribute
--
-- PARAMETERS
--   * p_name         The attribute name
--   * p_value        The attribute value to be written
--   * p_format       date format mask (default apx_json.c_timestamp_iso8601_ff_tzd)
--   * p_write_null   If true, write null values. If false (the default), do not
--                    write nulls.
--==============================================================================
procedure write (
    p_name        in varchar2,
    p_value       in timestamp with time zone,
    p_format      in varchar2    default c_timestamp_iso8601_ff_tzd,
    p_write_null  in boolean default false );

--==============================================================================
-- write an object attribute
--
-- PARAMETERS
--   * p_name         The attribute name
--   * p_value        The attribute value to be written
--   * p_write_null   If true, write null values. If false (the default), do not
--                    write nulls.
--==============================================================================
procedure write (
    p_name        in varchar2,
    p_value       in boolean,
    p_write_null  in boolean default false );

--==============================================================================
-- write an array attribute of type varchar2
--
-- PARAMETERS
--   * p_name         The attribute name
--   * p_values       The varchar2 array values to be written
--   * p_write_null   If true, write an empty array. If false (the default), do not
--                    write an empty array.
-- EXAMPLE
--   write { "array":[ "a", "b", "c" ] }
--
--   declare
--     l_values apex_t_varchar2 := apex_t_varchar2( 'a', 'b', 'c' );
--   begin
--     apx_JSON.open_object;                -- {
--     apx_JSON.write('array', l_values );  --   "array": [ "a", "b", "c" ]
--     apx_JSON.close_object;               -- }
--   end;
--==============================================================================
procedure write (
    p_name        in varchar2,
    p_values      in apx_t_varchar2,
    p_write_null  in boolean default false );

--==============================================================================
-- write an array attribute of type number
--
-- PARAMETERS
--   * p_name         The attribute name
--   * p_values       The number array values to be written
--   * p_write_null   If true, write an empty array. If false (the default), do not
--                    write an empty array.
-- EXAMPLE
--   write { "array":[ "a", "b", "c" ] }
--
--   declare
--     l_values apex_t_number := apex_t_number( 1, 2, 3 );
--   begin
--     apx_JSON.open_object;                -- {
--     apx_JSON.write('array', l_values );  --   "array": [ 1, 2, 3 ]
--     apx_JSON.close_object;               -- }
--   end;
--==============================================================================
procedure write (
    p_name        in varchar2,
    p_values      in apx_t_number,
    p_write_null  in boolean default false );

--==============================================================================
-- write an attribute where the value is an array that contains all rows that
-- the cursor returns. each row is a separate object.
--
-- If the query contains object type, collection or cursor columns, the
-- procedure uses write(name,<xmltype>) to generate JSON. See
-- write(name,<xmltype>) for further details. Otherwise, it uses DBMS_SQL to
-- fetch rows and the write() procedures for the appropriate column data types
-- for output. If the column type is varchar2 and the uppercase value is 'TRUE'
-- or 'FALSE', it generates boolean values.
--
-- PARAMETERS
--   * p_name         The attribute name
--   * p_cursor       The cursor
--
-- EXAMPLE
--   Write an array containing JSON objects for departments 10 and 20, as an
--   object member attribute.
--
--   declare
--     c sys_refcursor;
--   begin
--     open c for select deptno,
--                       dname,
--                       cursor(select empno,
--                                     ename
--                                from emp e
--                               where e.deptno=d.deptno) emps
--                  from dept d;
--     apx_JSON.open_object;
--     apx_JSON.  write('departments', c);
--     apx_JSON.close_object;
--   end;
--
--   { "departments":[
--         {"DEPTNO":10,
--          "DNAME":"ACCOUNTING",
--          "EMPS":[{"EMPNO":7839,"ENAME":"KING"}]},
--         ...
--        ,{"DEPTNO":40,"DNAME":"OPERATIONS","EMPS":null}] }
--==============================================================================
procedure write (
    p_name        in varchar2,
    p_cursor      in out nocopy sys_refcursor );

--==============================================================================
-- write an object attribute of type xmltype
--
-- The procedure uses a XSL transformation to generate JSON. To determine the
-- JSON type of values, it uses the following rules:
-- * If the value is empty, it generates a null value
-- * If upper(value) is TRUE, it generates a boolean true value
-- * If upper(value) is FALSE, it generates a boolean false value
-- * If the XPath number function returns true, it emits the value as is
-- * Otherwise, it enquotes the value (i.e. treats it as a JSON string)
--
-- PARAMETERS
--   * p_name         The attribute name
--   * p_value        The value to be written. The XML is converted to JSON.
--   * p_write_null   If true, write null values. If false (the default), do not
--                    write nulls.
--==============================================================================
procedure write (
    p_name        in varchar2,
    p_value       in sys.xmltype,
    p_write_null  in boolean default false );

--==============================================================================
-- write parsed json values
--
-- PARAMETERS
--   * p_values       parsed json members
--   * p_path         index into p_values
--   * p[0-4]         each %N in p_path will be replaced by pN and every
--                    i-th %s or %d will be replaced by the p[i-1]
--
-- EXAMPLE
--   parse a json string and write parts of it.
--
--   declare
--     j apx_JSON.t_values;
--   begin
--     apx_JSON.parse(j, '{ "foo": 3, "bar": { "x": 1, "y": 2 }}');
--     apx_JSON.write(j,'bar');             -- { "x": 1, "y": 2}
--   end;
--==============================================================================
procedure write (
    p_values      in t_values,
    p_path        in varchar2 default '.',
    p0            in varchar2 default null,
    p1            in varchar2 default null,
    p2            in varchar2 default null,
    p3            in varchar2 default null,
    p4            in varchar2 default null );

--==============================================================================
-- write parsed json values
--
-- PARAMETERS
--   * p_name         The attribute name
--   * p_values       parsed json members
--   * p_path         index into p_values
--   * p[0-4]         each %N in p_path will be replaced by pN and every
--                    i-th %s or %d will be replaced by the p[i-1]
--   * p_write_null   If true, write null values. If false (the default), do not
--                    write nulls.
--
-- EXAMPLE
--   parse a json string and write parts of it as an object member.
--
--   declare
--     j apx_JSON.t_values;
--   begin
--     apx_JSON.parse(j, '{ "foo": 3, "bar": { "x": 1, "y": 2 }}');
--     apx_JSON.open_object;                -- {
--     apx_JSON.write('parsed-bar',j,'bar');-- "parsed-bar":{ "x":1 ,"y":2 }
--     apx_JSON.close_object;               -- }
--   end;
--==============================================================================
procedure write (
    p_name        in varchar2,
    p_values      in t_values,
    p_path        in varchar2 default '.',
    p0            in varchar2 default null,
    p1            in varchar2 default null,
    p2            in varchar2 default null,
    p3            in varchar2 default null,
    p4            in varchar2 default null,
    p_write_null  in boolean default false );

--##############################################################################
--#
--# ORACLE REST STANDARD SUPPORT
--#
--# The Oracle Rest Service Standard defines a few characteristics for JSON
--# data. The APIs below help creating standard conforming output.
--#
--##############################################################################

--==============================================================================
-- utility record and table for item links (see link function for details)
--==============================================================================
type t_link is record (
    href       varchar2(4000),
    rel        varchar2(30),
    media_type varchar2(80),
    templated  boolean,
    method     varchar2(10),
    profile    varchar2(80) );
type t_links is table of t_link;

--==============================================================================
-- utility function to create a t_link record
--
-- PARAMETERS
--   * p_href       link target URI or URI template (see p_templated)
--   * p_rel        link relation type
--   * p_templated  if true, p_href is a URI template
--   * p_media_type expected mime type of the link target (RFC 2046)
--   * p_method     request method (e.g. GET, DELETE)
--   * p_profile    JSON schema that describes the resource
--
-- EXAMPLE
--   see write_links
--==============================================================================
function link (
    p_href       in varchar2,
    p_rel        in varchar2,
    p_templated  in boolean  default null,
    p_media_type in varchar2 default null,
    p_method     in varchar2 default null,
    p_profile    in varchar2 default null )
    return t_link;

--==============================================================================
-- writes "links" attribute with given values
--
-- PARAMETERS
--   * p_links     table of links
--
-- EXAMPLE
--   Write given links data.
--
--     begin
--       apx_JSON.open_object;
--       apx_JSON.  write_links (
--                       p_links => apx_JSON.t_links (
--                                      apx_JSON.link (
--                                          p_href => 'http://www.oracle.com',
--                                          p_rel  => 'self' )));
--       apx_JSON.close_object;
--     end;
--
--   Output:
--
--     {
--       "links": [
--         {
--           "href": "http://www.oracle.com",
--           "rel": "self"
--         }
--       ]
--     }
--==============================================================================
procedure write_links (
    p_links in t_links );

--==============================================================================
-- write values of given xmltype as "items" attribute.
--
-- PARAMETERS
--   * p_items      records to be written
--   * p_item_links links within each item record
--   * p_links      links for the whole item set
--
-- EXAMPLE
--   Write employee items collection
--
--     declare
--       c sys_refcursor;
--     begin
--       open c for select ename, empno from emp where deptno=20;
--       apx_JSON.write_items (
--           p_items      => c,
--           p_item_links => apx_JSON.t_links (
--                               apx_JSON.link (
--                                   p_href => 'f?p=&APP_ID.:EDIT_EMP:&SESSION.::::P99_EMPNO:#EMPNO#',
--                                   p_rel  => 'self' )),
--           p_links      => apx_JSON.t_links (
--                               apx_JSON.link (
--                                   p_href => 'f?p=&APP_ID.:EMPS:&SESSION.',
--                                   p_rel  => 'self' ),
--                               apx_JSON.link (
--                                   p_href       => '.../metadata/emps',
--                                   p_rel        => 'describedby',
--                                   p_media_type => 'application/json' ),
--                               apx_JSON.link (
--                                   p_href => 'f?p=&APP_ID.:EMPS:&SESSION.::::P98_DEPTNO:10',
--                                   p_rel  => 'start' ),
--                               apx_JSON.link (
--                                   p_href => 'f?p=&APP_ID.:EMPS:&SESSION.::::P98_DEPTNO:10',
--                                   p_rel  => 'prev' ),
--                               apx_JSON.link (
--                                   p_href => 'f?p=&APP_ID.:EMPS:&SESSION.::::P98_DEPTNO:30',
--                                   p_rel  => 'next' ),
--                               apx_JSON.link (
--                                   p_href => 'f?p=&APP_ID.:EDIT_EMPS:&SESSION.::::P98_DEPTNO:10',
--                                   p_rel => 'edit' )));
--     end;
--
--   Output:
--
--     { "items": [
--         { "ENAME": "employee 1",
--           "EMPNO": 4711,
--           "links": [
--             { "href": "href:f?p=&APP_ID.:EDIT_EMP:&SESSION.::::P99_EMPNO:4711" }
--           ]
--         },
--         { "ENAME": "employee 2",
--           "EMPNO": 4712,
--           "links": [
--             { "href": "href:f?p=&APP_ID.:EDIT_EMP:&SESSION.::::P99_EMPNO:4712" }
--           ]
--         }
--       ],
--       "links": [
--         { "href": "f?p=&APP_ID.:EMPS:&SESSION.", "rel": "self" },
--         { "href": ".../metadata/emps", "rel": "describedby", "type": "application/json" },
--         { "href": "f?p=&APP_ID.:EMPS:&SESSION.::::P98_DEPTNO:10", "rel": "start" },
--         { "href": "f?p=&APP_ID.:EMPS:&SESSION.::::P98_DEPTNO:10", "rel": "prev" },
--         { "href": "f?p=&APP_ID.:EMPS:&SESSION.::::P98_DEPTNO:30", "rel": "next" },
--         { "href": "f?p=&APP_ID.:EDIT_EMPS:&SESSION.::::P98_DEPTNO:10", "rel": "edit" }
--       ]
--     }
--==============================================================================
procedure write_items (
    p_items      in out nocopy sys_refcursor,
    p_item_links in            t_links default null,
    p_links      in            t_links default null );

--##############################################################################
--#
--# UNSAFE RAW OUTPUT
--#
--##############################################################################

--==============================================================================
-- write an unescaped array attribute. use the escaping write() procedures
-- instead, if possible.
--
-- PARAMETERS
--   * p_value    The value to be written
--
-- EXAMPLE
--   Write an array attribute that contains JSON
--
--   begin
--     apx_JSON.open_array;
--     apx_JSON.write_raw('{ "foo": 1, "bar": { "x": 1, "y": 2 }}');
--     apx_JSON.close_array;
--   end;
--==============================================================================
procedure write_raw (
    p_value  in varchar2 );

--==============================================================================
-- write an unescaped array attribute. use the escaping write() procedures
-- instead, if possible.
--
-- PARAMETERS
--   * p_value    The value to be written which can be longer than 32KB
--
-- EXAMPLE
--   Write an array attribute that contains JSON
--
--   declare
--       l_value apex_application_global.vc_arr2;
--   begin
--     l_value(1) := '{ "foo": 1,';
--     l_value(2) := '"bar": { "x": 1, "y": 2 }';
--     l_value(3) := '}';
--     apx_JSON.open_array;
--     apx_JSON.write_raw(l_value);
--     apx_JSON.close_array;
--   end;
--==============================================================================
procedure write_raw (
    p_value  in vc_arr2 );

--==============================================================================
-- write an unescaped object value. use the escaping write() procedures
-- instead, if possible.
--
-- PARAMETERS
--   * p_name         The attribute name
--   * p_value        The raw value to be written.
--
-- EXAMPLE
--   Write an object attribute that contains JSON
--
--   begin
--     apx_JSON.open_object;
--     apx_JSON.write_raw('foo', '[1, 2, 3]');
--     apx_JSON.close_object;
--   end;
--==============================================================================
procedure write_raw (
    p_name   in varchar2,
    p_value  in varchar2 );

end apx_json;
/
create or replace PACKAGE BODY apx_json AS
G_DB_CHARSET          VARCHAR2(255);

LF constant t_char := unistr('\000a');              -- line separator character
CR constant t_char := unistr('\000d');
CRLF constant varchar2(2) := CR||LF;
WS constant varchar2(5) := unistr(' \0009\000b')||CRLF; -- white space

c_html_whitelist_tags        constant varchar2(255) := '<h1>,</h1>,<h2>,</h2>,<h3>,</h3>,<h4>,</h4>,<p>,</p>,<b>,</b>,<strong>,</strong>,<i>,</i>,<em>,</em>,<ul>,</ul>,<ol>,</ol>,<li>,</li>,<dl>,</dl>,<dt>,</dt>,<dd>,</dd>,<pre>,</pre>,<code>,</code>,<br />,<br/>,<br>,<BR>,<hr/>';
BACKSPACE#                   CONSTANT BINARY_INTEGER := 8;
TAB#                         CONSTANT BINARY_INTEGER := 9;
LF#                          CONSTANT BINARY_INTEGER := 10;
CR#                          CONSTANT BINARY_INTEGER := 13;
SPACE#                       CONSTANT BINARY_INTEGER := 32;
HASH#                        CONSTANT BINARY_INTEGER := 35;
COMMA#                       CONSTANT BINARY_INTEGER := 44;
HYPHEN#                      CONSTANT BINARY_INTEGER := 45;
DOT#                         CONSTANT BINARY_INTEGER := 46;
ZERO#                        CONSTANT BINARY_INTEGER := 48;
NINE#                        CONSTANT BINARY_INTEGER := 57;
UP_A#                        CONSTANT BINARY_INTEGER := 65;
UP_Z#                        CONSTANT BINARY_INTEGER := 90;
BACKSLASH#                   CONSTANT BINARY_INTEGER := 92;
SLASH#                       CONSTANT BINARY_INTEGER := ASCII('/');
DOUBLEQUOTE#                 CONSTANT BINARY_INTEGER := ASCII('"');
UNDERSCORE#                  CONSTANT BINARY_INTEGER := 95;
LOW_A#                       CONSTANT BINARY_INTEGER := 97;
LOW_Z#                       CONSTANT BINARY_INTEGER := 122;

C_USERNAME_MAX_LENGTH          CONSTANT BINARY_INTEGER := 255;
G_BASIC_HTML_ESCAPING          BOOLEAN := FALSE;
G_NO_CHARSET_CONVERSION_NEEDED BOOLEAN := FALSE;

TYPE T_CONVERSION_MAP IS TABLE OF VARCHAR2(6) INDEX BY PLS_INTEGER;
G_JSON_MAP                     T_CONVERSION_MAP;
G_JSON_MAP_INITIALIZED         BOOLEAN := FALSE;

G_HTML_ATTRIBUTE_MAP           T_CONVERSION_MAP;
G_HTML_ATTR_MAP_INITIALIZED    BOOLEAN := FALSE;

type t_pos is record (
    line              binary_integer not null := 0, -- currrent line number
    col               binary_integer not null := 0, -- current column number
    idx               binary_integer not null := 0  -- character index
);

--==============================================================================
-- char_reader state
--==============================================================================
type t is record (
    --
    -- public fields (read/write)
    --
    input             vc_arr2,      -- input text
    is_line_separated boolean not null := true,     -- true if the char_reader should assume chr(10) between input(n) and input(n+1)
    --
    -- read-only fields
    --
    pos               t_pos,                        -- current line/column position
    --
    -- private fields
    --
    putback           varchar2(32767),              -- stack of unread characters
    putback_length    binary_integer not null := 0, -- length of putback
    cur_input         varchar2(32767),              -- copy of input(cur_input_idx) for performance
    cur_input_pos     binary_integer not null := 1, -- cursor position in cur_input
    cur_input_length  binary_integer not null := 0, -- length(cur_input)
    cur_input_idx     binary_integer not null := 0, -- index of cur_input within input. if 0 -> not initialized
    input_count       binary_integer not null := 0  -- input.count
);

C_WS            CONSTANT VARCHAR2(4) := UNISTR(' \0009\000a\000d');

C_LOWER_A#      CONSTANT PLS_INTEGER := ASCII('a');
C_LOWER_Z#      CONSTANT PLS_INTEGER := ASCII('z');
C_DOLLAR#       CONSTANT PLS_INTEGER := ASCII('$');
C_HASH#         CONSTANT PLS_INTEGER := ASCII('#');

TYPE T_LEXER IS RECORD (
    READER                   T,     
    POS                      T_POS, 
    NUMBER_VALUE             NUMBER,
    VARCHAR2_VALUE           VARCHAR2(32767),
    VARCHAR2_LENGTH          PLS_INTEGER,
    CLOB_WRITER              apx_T_CLOB_WRITER,
    IS_STRICT                BOOLEAN,
    PREV_NUMERIC_CHARS       VARCHAR2(2)
);
SUBTYPE T_SYMBOL IS BINARY_INTEGER RANGE 0 .. 11 NOT NULL;
C_SY_EOF             CONSTANT T_SYMBOL := 0;
C_SY_BEGIN_ARRAY     CONSTANT T_SYMBOL := 1; 
C_SY_BEGIN_OBJECT    CONSTANT T_SYMBOL := 2; 
C_SY_END_ARRAY       CONSTANT T_SYMBOL := 3; 
C_SY_END_OBJECT      CONSTANT T_SYMBOL := 4; 
C_SY_NAME_SEPARATOR  CONSTANT T_SYMBOL := 5; 
C_SY_VALUE_SEPARATOR CONSTANT T_SYMBOL := 6; 
C_SY_FALSE           CONSTANT T_SYMBOL := 7; 
C_SY_TRUE            CONSTANT T_SYMBOL := 8; 
C_SY_NULL            CONSTANT T_SYMBOL := 9; 
C_SY_NUMBER          CONSTANT T_SYMBOL := 10;
C_SY_VARCHAR2        CONSTANT T_SYMBOL := 11;

C_CHR7F           CONSTANT CHAR(1 BYTE) := UNISTR('\007F'); 
C_BS              CONSTANT CHAR(1 BYTE) := UNISTR('\0008');
C_FF              CONSTANT CHAR(1 BYTE) := UNISTR('\000C');
C_LF              CONSTANT CHAR(1 BYTE) := UNISTR('\000A');
C_CR              CONSTANT CHAR(1 BYTE) := UNISTR('\000D');
C_TAB             CONSTANT CHAR(1 BYTE) := UNISTR('\0009');

C_TAB#            CONSTANT BINARY_INTEGER := 9;
C_LF#             CONSTANT BINARY_INTEGER := 10;
C_CR#             CONSTANT BINARY_INTEGER := 13;
C_SPACE#          CONSTANT BINARY_INTEGER := 32;
C_A#              CONSTANT BINARY_INTEGER := ASCII('a');
C_B#              CONSTANT BINARY_INTEGER := ASCII('b');
C_E#              CONSTANT BINARY_INTEGER := ASCII('e');
C_F#              CONSTANT BINARY_INTEGER := ASCII('f');
C_N#              CONSTANT BINARY_INTEGER := ASCII('n');
C_R#              CONSTANT BINARY_INTEGER := ASCII('r');
C_T#              CONSTANT BINARY_INTEGER := ASCII('t');
C_U#              CONSTANT BINARY_INTEGER := ASCII('u');
C_Z#              CONSTANT BINARY_INTEGER := ASCII('z');
C_UPPER_A#        CONSTANT BINARY_INTEGER := ASCII('A');
C_UPPER_E#        CONSTANT BINARY_INTEGER := ASCII('E');
C_UPPER_Z#        CONSTANT BINARY_INTEGER := ASCII('Z');
C_0#              CONSTANT BINARY_INTEGER := ASCII('0');
C_9#              CONSTANT BINARY_INTEGER := ASCII('9');
C_BACKSLASH#      CONSTANT BINARY_INTEGER := ASCII('\');
C_SLASH#          CONSTANT BINARY_INTEGER := ASCII('/');
C_DOUBLEQUOTE#    CONSTANT BINARY_INTEGER := ASCII('"');
C_UNDERSCORE#     CONSTANT BINARY_INTEGER := ASCII('_');
C_BRACKET_OPEN#   CONSTANT BINARY_INTEGER := ASCII('[');
C_BRACKET_CLOSE#  CONSTANT BINARY_INTEGER := ASCII(']');
C_CBRACE_OPEN#    CONSTANT BINARY_INTEGER := ASCII('{');
C_CBRACE_CLOSE#   CONSTANT BINARY_INTEGER := ASCII('}');
C_COLON#          CONSTANT BINARY_INTEGER := ASCII(':');
C_COMMA#          CONSTANT BINARY_INTEGER := ASCII(',');
C_MINUS#          CONSTANT BINARY_INTEGER := ASCII('-');
C_PLUS#           CONSTANT BINARY_INTEGER := ASCII('+');
C_DOT#            CONSTANT BINARY_INTEGER := ASCII('.');

G_XML_TO_JSON        SYS.XMLTYPE;

G_NULL_XML_WRITER    apx_T_CLOB_WRITER;

C_STRINGIFY_LENGTH CONSTANT PLS_INTEGER := 5460;

TYPE T_OUTPUT IS RECORD (
    NESTING                  N_ARR,
    NESTING_LEVEL            NUMBER            NOT NULL := 0,
    NESTING_AT_CURRENT_LEVEL PLS_INTEGER       NOT NULL := 0,
    INDENT                   PLS_INTEGER       NOT NULL := 0,
    HTTP_HEADER              BOOLEAN           NOT NULL := TRUE,
    HTTP_CACHE               BOOLEAN           NOT NULL := FALSE,
    HTTP_CACHE_ETAG          VARCHAR2(4000) );
SUBTYPE T_NESTING_VALUE IS PLS_INTEGER RANGE -2..2;
C_NESTING_OPENED_ARRAY  CONSTANT T_NESTING_VALUE := -2;
C_NESTING_OPENED_OBJECT CONSTANT T_NESTING_VALUE := -1;
C_NESTING_IN_OBJECT     CONSTANT T_NESTING_VALUE := 1;
G_OUTPUT T_OUTPUT;
G_WRITER apx_T_WRITER := apx_T_HTP_WRITER();



TYPE T_SUBSTITUTION IS RECORD (
    NAME         VARCHAR2(128),
    NAME_PATTERN VARCHAR2(128),
    VAL          VARCHAR2(32767) );
TYPE T_SUBSTITUTIONS IS TABLE OF T_SUBSTITUTION INDEX BY PLS_INTEGER;
G_LINK_SUBSTITUTIONS T_SUBSTITUTIONS;

FUNCTION ISALNUM (
    P_ASCII IN PLS_INTEGER )
    RETURN BOOLEAN
IS
BEGIN
    RETURN    P_ASCII BETWEEN LOW_A# AND LOW_Z#
           OR P_ASCII BETWEEN UP_A#  AND UP_Z#
           OR P_ASCII BETWEEN ZERO#  AND NINE#;
END ISALNUM;

FUNCTION JSON_MAP_CHAR (
    P_CHAR  IN VARCHAR2,
    P_ASCII IN PLS_INTEGER )
    RETURN VARCHAR2
IS
BEGIN
    PRAGMA INLINE(ISALNUM,'YES');
    RETURN CASE
             WHEN P_ASCII = BACKSLASH# THEN '\u'
             WHEN P_ASCII = DOUBLEQUOTE# THEN '\"'
             WHEN P_ASCII = SLASH# THEN '\/'
             WHEN P_ASCII = BACKSPACE# THEN '\b'
             WHEN P_ASCII = LF# THEN '\n'
             WHEN P_ASCII = CR# THEN '\r'
             WHEN P_ASCII = TAB# THEN '\t'

             WHEN ISALNUM(P_ASCII)
               OR P_ASCII IN (COMMA#, DOT#, UNDERSCORE#)
             THEN P_CHAR
             WHEN P_ASCII BETWEEN 32 AND 127
              AND INSTR('&<>"''`/\', P_CHAR) = 0
             THEN P_CHAR
             ELSE '\u'||LTRIM(TO_CHAR(P_ASCII, '0XXX'))
           END;
END JSON_MAP_CHAR;

FUNCTION CREATE_JSON_MAP
    RETURN T_CONVERSION_MAP
IS
    L_ESCAPE_MAP T_CONVERSION_MAP;
    L_CHAR       VARCHAR2(1 CHAR);
BEGIN
    FOR I IN 0 .. 127 LOOP
        L_CHAR := CHR(I);
        PRAGMA INLINE(JSON_MAP_CHAR,'YES');
        L_ESCAPE_MAP(I) := JSON_MAP_CHAR (
                               P_ASCII => I,
                               P_CHAR  => L_CHAR );
    END LOOP;

    RETURN L_ESCAPE_MAP;
END CREATE_JSON_MAP;

FUNCTION JSON ( P_STRING  IN VARCHAR2 )
    RETURN VARCHAR2
IS
    L_TEXT   VARCHAR2(32767);
    L_LENGTH PLS_INTEGER;
    L_RESULT VARCHAR2(32767);
    L_CHAR   VARCHAR2(1 CHAR);
    L_ASCII  PLS_INTEGER;
BEGIN
    IF P_STRING IS NOT NULL THEN
        IF NOT G_JSON_MAP_INITIALIZED THEN
            G_JSON_MAP             := CREATE_JSON_MAP;
            G_JSON_MAP_INITIALIZED := TRUE;
        END IF;

        L_TEXT   := ASCIISTR(P_STRING);
        L_LENGTH := LENGTH(L_TEXT);

        FOR I IN 1 .. L_LENGTH LOOP
            L_CHAR  := SUBSTR(L_TEXT, I, 1);
            L_ASCII := ASCII(L_CHAR);
            L_RESULT := L_RESULT ||
                        G_JSON_MAP(L_ASCII);
        END LOOP;
    END IF;

    RETURN L_RESULT;
END JSON;

FUNCTION HTML_QUICK_REPLACE (
    P_STRING IN VARCHAR2 )
    RETURN VARCHAR2
IS
BEGIN
    RETURN REPLACE(REPLACE(REPLACE(
           REPLACE(REPLACE(REPLACE(
               P_STRING,
               '&',  '&amp;'),
               '"',  '&quot;'),
               '<',  '&lt;'),
               '>',  '&gt;'),
               '''', '&#x27;'),
               '/',  '&#x2F;');
END HTML_QUICK_REPLACE;


FUNCTION HTML_SLOW_REPLACE (
    P_STRING IN VARCHAR2 )
    RETURN VARCHAR2
IS
    L_TEXT        VARCHAR2(32767);
    L_START       BINARY_INTEGER;
    L_POS         BINARY_INTEGER;
    L_HEX         VARCHAR2(5);
    L_RESULT      VARCHAR2(32767);
BEGIN
    PRAGMA INLINE(HTML_QUICK_REPLACE,'YES');
    L_TEXT := ASCIISTR (
                  HTML_QUICK_REPLACE (
                      P_STRING => P_STRING ));

    L_START := 1;
    L_POS   := INSTR(L_TEXT, '\');
    WHILE L_POS > 0 LOOP



        IF L_POS > L_START THEN
            L_RESULT := L_RESULT || SUBSTR(L_TEXT, L_START, L_POS - L_START);
        END IF;



        L_HEX := SUBSTR(L_TEXT, L_POS+1, 4);
        IF L_HEX LIKE '00%' THEN
            IF L_HEX = '005C' THEN
                L_RESULT := L_RESULT || '\';
            ELSE
                L_RESULT := L_RESULT || '&#x' || SUBSTR(L_HEX, 3) || ';';
            END IF;
        ELSE
            L_RESULT := L_RESULT || '&#x' || L_HEX || ';';
        END IF;



        L_START := L_POS + 5;
        L_POS   := INSTR(L_TEXT, '\', L_START);
    END LOOP;



    L_RESULT := L_RESULT || SUBSTR(L_TEXT, L_START);

    RETURN L_RESULT;
END HTML_SLOW_REPLACE;

FUNCTION HTML (
    P_STRING IN VARCHAR2 )
    RETURN VARCHAR2
IS
    L_RESULT           VARCHAR2(32767);
    C_SLOW_REPL_LENGTH CONSTANT BINARY_INTEGER := 6553; 
    L_ORIG_LENGTH      BINARY_INTEGER;
    L_POS              BINARY_INTEGER;
BEGIN
    IF G_BASIC_HTML_ESCAPING THEN
        L_RESULT := SYS.HTF.ESCAPE_SC(P_STRING);
    ELSIF G_NO_CHARSET_CONVERSION_NEEDED THEN
        PRAGMA INLINE(HTML_QUICK_REPLACE,'YES');
        L_RESULT := HTML_QUICK_REPLACE (
                        P_STRING => P_STRING );
    ELSE
        L_ORIG_LENGTH := LENGTH(P_STRING);

        IF G_NO_CHARSET_CONVERSION_NEEDED
            AND L_ORIG_LENGTH = LENGTHB(P_STRING)
        THEN
            PRAGMA INLINE(HTML_QUICK_REPLACE,'YES');
            L_RESULT := HTML_QUICK_REPLACE (
                            P_STRING => P_STRING );
        ELSIF L_ORIG_LENGTH <= C_SLOW_REPL_LENGTH THEN
            PRAGMA INLINE(HTML_SLOW_REPLACE,'YES');
            L_RESULT := HTML_SLOW_REPLACE (
                            P_STRING => P_STRING );
        ELSE
            PRAGMA INLINE(HTML_SLOW_REPLACE,'YES');
            L_RESULT := HTML_SLOW_REPLACE (
                            P_STRING => SUBSTR(P_STRING, 1, C_SLOW_REPL_LENGTH ));

            L_POS := 1+C_SLOW_REPL_LENGTH;

            WHILE L_POS <= L_ORIG_LENGTH LOOP
                PRAGMA INLINE(HTML_SLOW_REPLACE,'YES');
                L_RESULT := L_RESULT ||
                            HTML_SLOW_REPLACE (
                                P_STRING => SUBSTR(P_STRING, L_POS, C_SLOW_REPL_LENGTH ));

                L_POS := L_POS + C_SLOW_REPL_LENGTH;
            END LOOP;

        END IF;
    END IF;

    RETURN L_RESULT;
END HTML;


FUNCTION HTML_TRUNC (
    P_STRING            IN VARCHAR2,
    P_LENGTH            IN NUMBER DEFAULT 4000 )
    RETURN VARCHAR2
IS
    L_RESULT        VARCHAR2(32767);
    L_RESULT_LENGTH PLS_INTEGER := 0;
    L_CHUNK         VARCHAR2(32767);
    L_CHUNK_LENGTH  PLS_INTEGER;
    L_START         PLS_INTEGER := 1;
    L_COPY_LENGTH   PLS_INTEGER;
BEGIN
    IF P_STRING IS NOT NULL AND P_LENGTH > 0 THEN
        LOOP
            L_CHUNK        := HTML( SUBSTRB( P_STRING, L_START, 4000 ) );
            L_CHUNK_LENGTH := NVL( LENGTHB( L_CHUNK ), 0);
            L_COPY_LENGTH  := LEAST( L_CHUNK_LENGTH, P_LENGTH - L_RESULT_LENGTH );

            EXIT WHEN L_COPY_LENGTH = 0;

            IF L_COPY_LENGTH = L_CHUNK_LENGTH THEN
                L_RESULT := L_RESULT || L_CHUNK;
                L_START  := L_START + 4000;
            ELSE
                L_RESULT := L_RESULT || SUBSTRB( L_CHUNK, 1, L_COPY_LENGTH );
            END IF;

            L_RESULT_LENGTH := L_RESULT_LENGTH + L_COPY_LENGTH;

            EXIT WHEN L_COPY_LENGTH < L_CHUNK_LENGTH OR L_RESULT_LENGTH >= P_LENGTH;
        END LOOP;

        IF L_RESULT_LENGTH > P_LENGTH THEN
            L_RESULT := REGEXP_REPLACE (
                            SUBSTRB (
                                L_RESULT,
                                1,
                                P_LENGTH ),
                            '&[^;]{0,6}$' );
        END IF;
    END IF;

    RETURN L_RESULT;
EXCEPTION WHEN OTHERS THEN
    RAISE;
END HTML_TRUNC;


FUNCTION HTML_TRUNC (
    P_STRING            IN CLOB,
    P_LENGTH            IN NUMBER DEFAULT 4000 )
    RETURN VARCHAR2
IS
BEGIN
    IF P_STRING IS NOT NULL AND P_LENGTH > 0 THEN
        RETURN HTML_TRUNC (
                   P_STRING    => SYS.DBMS_LOB.SUBSTR(P_STRING, LEAST(P_LENGTH, 32767)),
                   P_LENGTH    => P_LENGTH );
    ELSE
        RETURN NULL;
    END IF;
END HTML_TRUNC;

FUNCTION HTML_ATTRIBUTE_MAP_CHAR (
    P_CHAR  IN VARCHAR2,
    P_ASCII IN PLS_INTEGER )
    RETURN VARCHAR2
IS
BEGIN
    PRAGMA INLINE(ISALNUM,'YES');
    RETURN CASE

           WHEN ISALNUM(P_ASCII)
               OR P_ASCII IN (COMMA#, DOT#, HYPHEN#, UNDERSCORE#)
           THEN P_CHAR
           WHEN P_ASCII = BACKSLASH# THEN '\u'
           ELSE '&#x'||
                LTRIM(TO_CHAR(P_ASCII, 'XX'))||
                ';'
           END;
END HTML_ATTRIBUTE_MAP_CHAR;





FUNCTION CREATE_HTML_ATTRIBUTE_MAP
    RETURN T_CONVERSION_MAP
IS
    L_HTML_ATTRIBUTE_MAP T_CONVERSION_MAP;
    L_CHAR           VARCHAR2(1 CHAR);
BEGIN
    FOR I IN 0 .. 127 LOOP
        L_CHAR := CHR(I);
        PRAGMA INLINE(HTML_ATTRIBUTE_MAP_CHAR,'YES');
        L_HTML_ATTRIBUTE_MAP(I) := HTML_ATTRIBUTE_MAP_CHAR (
                                   P_ASCII => I,
                                   P_CHAR  => L_CHAR );
    END LOOP;

    RETURN L_HTML_ATTRIBUTE_MAP;
END CREATE_HTML_ATTRIBUTE_MAP;


FUNCTION HTML_ATTRIBUTE (
    P_STRING IN VARCHAR2 )
    RETURN VARCHAR2
IS
    L_TEXT   VARCHAR2(32767);
    L_LENGTH PLS_INTEGER;
    I        BINARY_INTEGER;
    L_RESULT VARCHAR2(32767);
    L_CHAR   VARCHAR2(1);
    L_HEX    VARCHAR2(4);
    L_ASCII  PLS_INTEGER;
BEGIN
    IF P_STRING IS NOT NULL THEN



        IF NOT G_HTML_ATTR_MAP_INITIALIZED THEN
            G_HTML_ATTRIBUTE_MAP        := CREATE_HTML_ATTRIBUTE_MAP;
            G_HTML_ATTR_MAP_INITIALIZED := TRUE;
        END IF;



        L_TEXT   := ASCIISTR(P_STRING);
        L_LENGTH := LENGTH(L_TEXT);
        I        := 1;



        WHILE I <= L_LENGTH LOOP
            L_CHAR  := SUBSTR(L_TEXT, I, 1);
            L_ASCII := ASCII(L_CHAR);

            IF L_ASCII = BACKSLASH# THEN



                L_HEX    := SUBSTR(L_TEXT, I+1, 4);
                L_RESULT := L_RESULT||
                            '&#x'||
                            CASE
                            WHEN L_HEX LIKE '00%' THEN SUBSTR(L_HEX, 3)
                            ELSE L_HEX
                            END||
                            ';';
                I        := I + 5;
            ELSE
                L_RESULT := L_RESULT||G_HTML_ATTRIBUTE_MAP(L_ASCII);
                I        := I + 1;
            END IF;
        END LOOP;
    END IF;

    RETURN L_RESULT;
END HTML_ATTRIBUTE;

PROCEDURE READ (
    P_THIS IN OUT NOCOPY T,
    P_CHAR IN OUT NOCOPY T_CHAR )
IS
BEGIN
    IF P_THIS.PUTBACK IS NOT NULL THEN



        IF P_THIS.PUTBACK_LENGTH = 1 THEN
            P_CHAR                := P_THIS.PUTBACK;
            P_THIS.PUTBACK        := NULL;
            P_THIS.PUTBACK_LENGTH := 0;
        ELSE
            P_CHAR                := SUBSTR(P_THIS.PUTBACK,1,1);
            P_THIS.PUTBACK        := SUBSTR(P_THIS.PUTBACK,2);
            P_THIS.PUTBACK_LENGTH := P_THIS.PUTBACK_LENGTH-1;
        END IF;
    ELSIF P_THIS.CUR_INPUT_POS <= P_THIS.CUR_INPUT_LENGTH THEN



        P_CHAR               := SUBSTR(P_THIS.CUR_INPUT, P_THIS.CUR_INPUT_POS, 1);
        P_THIS.CUR_INPUT_POS := P_THIS.CUR_INPUT_POS + 1;
    ELSE



        IF P_THIS.INPUT_COUNT = 0 THEN
            P_THIS.INPUT_COUNT := P_THIS.INPUT.COUNT;
            IF P_THIS.INPUT_COUNT = 0 THEN
                P_CHAR := NULL;
                RETURN;
            END IF;
            P_THIS.CUR_INPUT_IDX    := 1;
            P_THIS.CUR_INPUT        := P_THIS.INPUT(1);
            P_THIS.CUR_INPUT_POS    := 1;
            P_THIS.CUR_INPUT_LENGTH := NVL(LENGTH(P_THIS.CUR_INPUT), 0);
            P_THIS.POS.LINE         := 1;
        END IF;




        WHILE P_THIS.CUR_INPUT_POS > P_THIS.CUR_INPUT_LENGTH LOOP
            IF P_THIS.CUR_INPUT_IDX >= P_THIS.INPUT_COUNT THEN
                P_CHAR := NULL;
                RETURN;
            END IF;

            P_THIS.CUR_INPUT_IDX    := P_THIS.CUR_INPUT_IDX + 1;
            P_THIS.CUR_INPUT        := P_THIS.INPUT(P_THIS.CUR_INPUT_IDX);
            P_THIS.CUR_INPUT_POS    := 1;
            P_THIS.CUR_INPUT_LENGTH := NVL(LENGTH(P_THIS.CUR_INPUT), 0);
            IF P_THIS.IS_LINE_SEPARATED THEN
                P_THIS.POS.LINE := P_THIS.POS.LINE+1;
                P_THIS.POS.COL  := 0;
            END IF;
        END LOOP;



        P_CHAR               := SUBSTR(P_THIS.CUR_INPUT, P_THIS.CUR_INPUT_POS, 1);
        P_THIS.CUR_INPUT_POS := P_THIS.CUR_INPUT_POS + 1;
    END IF;



    IF P_CHAR = LF THEN
        P_THIS.POS.LINE := P_THIS.POS.LINE + 1;
        P_THIS.POS.COL  := 0;
    ELSE
        P_THIS.POS.COL  := P_THIS.POS.COL+1;
    END IF;
    P_THIS.POS.IDX := P_THIS.POS.IDX+1;

END READ;


PROCEDURE READ_NON_WS (
    P_THIS IN OUT NOCOPY T,
    P_CHAR IN OUT NOCOPY T_CHAR )
IS
BEGIN
    LOOP
        PRAGMA INLINE(READ,'YES');
        READ (
            P_THIS => P_THIS,
            P_CHAR => P_CHAR );

        EXIT WHEN P_CHAR IS NULL OR INSTR(C_WS, P_CHAR) = 0;
    END LOOP;
END READ_NON_WS;

PROCEDURE UNREAD (
    P_THIS IN OUT NOCOPY T,
    P_CHAR IN T_CHAR )
IS
BEGIN
    IF P_CHAR IS NULL THEN
        RETURN;
    END IF;

    IF P_CHAR = LF THEN
        P_THIS.POS.LINE := P_THIS.POS.LINE - 1;
        P_THIS.POS.COL  := 0;
    ELSE
        P_THIS.POS.COL := P_THIS.POS.COL-1;
    END IF;
    P_THIS.POS.IDX := P_THIS.POS.IDX-1;

    P_THIS.PUTBACK        := P_CHAR||P_THIS.PUTBACK;
    P_THIS.PUTBACK_LENGTH := P_THIS.PUTBACK_LENGTH+1;
END UNREAD;

PROCEDURE READ_PLSQL_IDENTIFER_CHARS (
    P_THIS   IN OUT NOCOPY T,
    P_RESULT IN OUT NOCOPY VARCHAR2 )
IS
    C T_CHAR;
    A PLS_INTEGER;
BEGIN
    LOOP
        READ (
            P_THIS => P_THIS,
            P_CHAR => C );

        EXIT WHEN C IS NULL;

        A := ASCII(C);

        IF     A BETWEEN C_LOWER_A# AND C_LOWER_Z#
            OR A BETWEEN C_UPPER_A# AND C_UPPER_Z#
            OR A BETWEEN C_0#       AND C_9#
            OR A IN (C_UNDERSCORE#, C_DOLLAR#, C_HASH#)
        THEN
            P_RESULT := P_RESULT||C;
        ELSE
            PRAGMA INLINE(UNREAD,'YES');
            UNREAD (
                P_THIS => P_THIS,
                P_CHAR => C );
            EXIT;
        END IF;
    END LOOP;
END READ_PLSQL_IDENTIFER_CHARS;


FUNCTION READ_UNTIL (
    P_THIS IN OUT NOCOPY T,
    P_CHAR IN            T_CHAR )
    RETURN T_CHAR
IS
    L_CHAR T_CHAR;
BEGIN
    LOOP
        PRAGMA INLINE(READ,'YES');
        READ (
            P_THIS => P_THIS,
            P_CHAR => L_CHAR );

        EXIT WHEN L_CHAR IS NULL OR L_CHAR = P_CHAR;
    END LOOP;

    RETURN L_CHAR;
END READ_UNTIL;


FUNCTION READ_UNTIL (
    P_THIS       IN OUT NOCOPY T,
    P_CHAR       IN            T_CHAR,
    P_ESC_CHAR   IN            T_CHAR      DEFAULT NULL,
    P_MAX_LENGTH IN            PLS_INTEGER DEFAULT 32767,
    P_RESULT     IN OUT NOCOPY VARCHAR2 )
    RETURN T_CHAR
IS
    L_CHAR T_CHAR;
BEGIN
    FOR I IN 1 .. 32768 LOOP
        PRAGMA INLINE(READ,'YES');
        READ (
            P_THIS => P_THIS,
            P_CHAR => L_CHAR );

        EXIT WHEN L_CHAR IS NULL OR I > P_MAX_LENGTH OR L_CHAR IN (P_CHAR, P_ESC_CHAR);

        P_RESULT := P_RESULT||L_CHAR;
    END LOOP;

    RETURN L_CHAR;
END READ_UNTIL;






FUNCTION ENQUOTE_LITERAL (
    P_STR IN VARCHAR2 )
    RETURN VARCHAR2
IS
BEGIN
    RETURN SYS.DBMS_ASSERT.ENQUOTE_LITERAL (
               STR => REPLACE(P_STR,'''','''''') );
END ENQUOTE_LITERAL;

FUNCTION NEXT_CHUNK (
    P_STR    IN            CLOB,
    P_CHUNK  OUT           NOCOPY VARCHAR2,
    P_OFFSET IN OUT NOCOPY PLS_INTEGER,
    P_AMOUNT IN            PLS_INTEGER DEFAULT 8191 )
    RETURN BOOLEAN
IS
    L_OFFSET PLS_INTEGER;
    L_AMOUNT PLS_INTEGER := P_AMOUNT;
BEGIN
    IF P_STR IS NULL THEN
        RETURN FALSE;
    END IF;

    IF P_OFFSET > 0 THEN
        L_OFFSET := P_OFFSET;
    ELSE
        L_OFFSET := 1;
    END IF;

    SYS.DBMS_LOB.READ (
        LOB_LOC => P_STR,
        AMOUNT  => L_AMOUNT,
        OFFSET  => L_OFFSET,
        BUFFER  => P_CHUNK );
    P_OFFSET := L_OFFSET + L_AMOUNT;
    RETURN TRUE;
EXCEPTION WHEN NO_DATA_FOUND THEN
    RETURN FALSE;
WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20001,'next_chunk(ofs='||L_OFFSET||',amt='||L_AMOUNT||'):'||SQLERRM);
END NEXT_CHUNK;

FUNCTION SPLIT (
    P_STR   IN VARCHAR2,
    P_SEP   IN VARCHAR2    DEFAULT unistr('\000a'),
    P_LIMIT IN PLS_INTEGER DEFAULT NULL )
    RETURN apx_T_VARCHAR2
IS
    L_RESULT       apx_T_VARCHAR2  := apx_T_VARCHAR2();
    L_STR_LENGTH   PLS_INTEGER;
    L_SEP_LENGTH   PLS_INTEGER;
    L_SEP_TYPE     BOOLEAN; 
    L_START        PLS_INTEGER NOT NULL := 1;
    L_FOUND        PLS_INTEGER;
    L_COUNT        PLS_INTEGER NOT NULL := 1;
BEGIN
    IF P_STR IS NULL THEN RETURN L_RESULT; END IF;

    L_STR_LENGTH := LENGTH(P_STR);

    IF P_SEP IS NULL THEN
        L_SEP_LENGTH := 0;
    ELSE
        L_SEP_LENGTH := LENGTH(P_SEP);
        L_SEP_TYPE := L_SEP_LENGTH > 1;
    END IF;

    LOOP
        
        
        
        IF L_COUNT >= P_LIMIT THEN
            L_FOUND := 0;
        ELSIF L_SEP_TYPE IS NULL THEN
            IF L_START >= L_STR_LENGTH THEN
                L_FOUND := 0;
            ELSE
                L_FOUND := L_START+1;
            END IF;
        ELSIF L_SEP_TYPE THEN
            L_FOUND := REGEXP_INSTR(P_STR, P_SEP, L_START);
        ELSE
            L_FOUND := INSTR(P_STR, P_SEP, L_START);
        END IF;
        
        IF L_FOUND > 0 THEN
            L_RESULT.EXTEND;
            L_RESULT(L_COUNT) := SUBSTR(P_STR, L_START, L_FOUND-L_START);
            IF L_SEP_TYPE THEN
                L_SEP_LENGTH := NVL(LENGTH(REGEXP_SUBSTR(P_STR, P_SEP, L_START)), 0);
            END IF;
            L_START := L_FOUND + L_SEP_LENGTH;
        ELSE
            L_RESULT.EXTEND;
            L_RESULT(L_COUNT) := SUBSTR(P_STR, L_START, L_STR_LENGTH-L_START+1);
            EXIT;
        END IF;
        
        L_COUNT := L_COUNT + 1;
    END LOOP;

    RETURN L_RESULT;
END SPLIT;

PROCEDURE PUSH (
    P_TABLE IN OUT NOCOPY apx_T_VARCHAR2,
    P_VALUE IN            VARCHAR2 )
IS
BEGIN
    IF P_TABLE IS NULL THEN
        P_TABLE := apx_T_VARCHAR2(P_VALUE);
    ELSE
        P_TABLE.EXTEND;
        P_TABLE(P_TABLE.COUNT) := P_VALUE;
    END IF;
END PUSH;


PROCEDURE PUSH (
    P_TABLE IN OUT NOCOPY apx_T_NUMBER,
    P_VALUE IN NUMBER )
IS
BEGIN
    IF P_TABLE IS NULL THEN
        P_TABLE := apx_T_NUMBER(P_VALUE);
    ELSE
        P_TABLE.EXTEND;
        P_TABLE(P_TABLE.COUNT) := P_VALUE;
    END IF;
END PUSH;


PROCEDURE PUSH (
    P_TABLE  IN OUT NOCOPY apx_T_VARCHAR2,
    P_VALUES IN            apx_T_VARCHAR2 )
IS
    L_VALUES_COUNT PLS_INTEGER;
    L_TABLE_IDX    PLS_INTEGER;
BEGIN
    IF P_TABLE IS NULL THEN
        IF P_VALUES IS NULL THEN
            P_TABLE := apx_T_VARCHAR2();
        ELSE
            P_TABLE := P_VALUES;
        END IF;
    ELSIF P_VALUES IS NOT NULL THEN
        L_VALUES_COUNT := P_VALUES.COUNT;
        L_TABLE_IDX    := P_TABLE.COUNT;
        P_TABLE.EXTEND(L_VALUES_COUNT);
        FOR I IN 1 .. L_VALUES_COUNT LOOP
            P_TABLE(L_TABLE_IDX+I) := P_VALUES(I);
        END LOOP;
    END IF;
END PUSH;


PROCEDURE PUSH (
    P_TABLE  IN OUT NOCOPY apx_T_VARCHAR2,
    P_VALUES IN            VC_ARR2 )
IS
    L_VALUES_COUNT PLS_INTEGER;
    L_TABLE_IDX    PLS_INTEGER;
    L_VALUES_IDX   PLS_INTEGER;
BEGIN
    IF P_TABLE IS NULL THEN
        P_TABLE     := apx_T_VARCHAR2();
        L_TABLE_IDX := 1;
    ELSE
        L_TABLE_IDX := P_TABLE.COUNT+1;
    END IF;

    L_VALUES_COUNT := P_VALUES.COUNT;
    IF L_VALUES_COUNT > 0 THEN
        P_TABLE.EXTEND(L_VALUES_COUNT);
        L_VALUES_IDX := P_VALUES.FIRST;
        WHILE L_VALUES_IDX IS NOT NULL LOOP
            P_TABLE(L_TABLE_IDX) := P_VALUES(L_VALUES_IDX);
            L_VALUES_IDX         := P_VALUES.NEXT(L_VALUES_IDX);
            L_TABLE_IDX          := L_TABLE_IDX + 1;
        END LOOP;
    END IF;
END PUSH;

FUNCTION SPLIT (
    P_STR   IN CLOB,
    P_SEP   IN VARCHAR2    DEFAULT unistr('\000a'))
    RETURN apx_T_VARCHAR2
IS
    L_RESULT        apx_T_VARCHAR2  := apx_T_VARCHAR2();
    L_SEP_LENGTH    PLS_INTEGER;
    L_SEP_TYPE      BOOLEAN; 
    L_BUFFER        VARCHAR2(32767);
    L_BUFFER_NEW    VARCHAR2(32767);
    L_BUFFER_LENGTH PLS_INTEGER;
    L_LOB_START     PLS_INTEGER NOT NULL := 1;
    C_LOB_AMOUNT    CONSTANT PLS_INTEGER := 8191;
    L_LOB_AMOUNT    PLS_INTEGER;
    L_START         PLS_INTEGER NOT NULL := 1;
    L_FOUND         PLS_INTEGER;
BEGIN
    IF P_STR IS NULL THEN RETURN L_RESULT; END IF;

    IF P_SEP IS NULL THEN
        L_SEP_LENGTH := 0;
    ELSE
        L_SEP_LENGTH := LENGTH(P_SEP);
        L_SEP_TYPE   := L_SEP_LENGTH > 1;
    END IF;

    LOOP
        
        
        
        IF L_BUFFER IS NULL THEN
            L_LOB_AMOUNT := C_LOB_AMOUNT;
        ELSE
            L_LOB_AMOUNT := LEAST(C_LOB_AMOUNT, 32767-LENGTH(L_BUFFER));
            IF L_LOB_AMOUNT = 0 THEN
                
                
                
                RAISE VALUE_ERROR;
            END IF;
        END IF;
        
        
        
        PRAGMA INLINE(NEXT_CHUNK, 'YES');
        IF NEXT_CHUNK (
               P_STR    => P_STR,
               P_CHUNK  => L_BUFFER_NEW,
               P_OFFSET => L_LOB_START,
               P_AMOUNT => L_LOB_AMOUNT )
        THEN
            
            
            
            IF L_BUFFER IS NOT NULL THEN
                L_BUFFER := L_BUFFER || L_BUFFER_NEW;
            ELSE
                L_BUFFER := L_BUFFER_NEW;
            END IF;
            IF L_SEP_TYPE IS NULL THEN
                L_BUFFER_LENGTH := NVL(LENGTH(L_BUFFER), 0);
            END IF;
            
            
            
            L_START := 1;
            LOOP
                
                
                
                IF L_SEP_TYPE IS NULL THEN
                    IF L_START > L_BUFFER_LENGTH THEN
                        L_FOUND := 0;
                    ELSE
                        L_FOUND := L_START+1;
                    END IF;
                ELSIF L_SEP_TYPE THEN
                    L_FOUND := REGEXP_INSTR(L_BUFFER, P_SEP, L_START);
                ELSE
                    L_FOUND := INSTR(L_BUFFER, P_SEP, L_START);
                END IF;
                
                IF L_FOUND > 0 THEN
                    
                    
                    
                    PRAGMA INLINE(PUSH, 'YES');
                    PUSH (
                        P_TABLE => L_RESULT,
                        P_VALUE => SUBSTR(L_BUFFER, L_START, L_FOUND-L_START) );
                    IF L_SEP_TYPE THEN
                        L_SEP_LENGTH := NVL(LENGTH(REGEXP_SUBSTR(L_BUFFER, P_SEP, L_START)), 0);
                    END IF;
                    
                    
                    
                    L_START := L_FOUND + L_SEP_LENGTH;
                ELSE
                    
                    
                    
                    L_BUFFER := SUBSTR(L_BUFFER, L_START);
                    EXIT;
                END IF;
            END LOOP;
        ELSE
            IF L_BUFFER IS NOT NULL THEN
                
                
                
                PRAGMA INLINE(PUSH, 'YES');
                PUSH (
                    P_TABLE => L_RESULT,
                    P_VALUE => L_BUFFER );
            END IF;
            EXIT;
        END IF;
    END LOOP;

    RETURN L_RESULT;
END SPLIT;

FUNCTION FORMAT (
    P_MESSAGE    IN VARCHAR2,
    P0           IN VARCHAR2    DEFAULT NULL,
    P1           IN VARCHAR2    DEFAULT NULL,
    P2           IN VARCHAR2    DEFAULT NULL,
    P3           IN VARCHAR2    DEFAULT NULL,
    P4           IN VARCHAR2    DEFAULT NULL,
    P5           IN VARCHAR2    DEFAULT NULL,
    P6           IN VARCHAR2    DEFAULT NULL,
    P7           IN VARCHAR2    DEFAULT NULL,
    P8           IN VARCHAR2    DEFAULT NULL,
    P9           IN VARCHAR2    DEFAULT NULL,
    P10          IN VARCHAR2    DEFAULT NULL,
    P11          IN VARCHAR2    DEFAULT NULL,
    P12          IN VARCHAR2    DEFAULT NULL,
    P13          IN VARCHAR2    DEFAULT NULL,
    P14          IN VARCHAR2    DEFAULT NULL,
    P15          IN VARCHAR2    DEFAULT NULL,
    P16          IN VARCHAR2    DEFAULT NULL,
    P17          IN VARCHAR2    DEFAULT NULL,
    P18          IN VARCHAR2    DEFAULT NULL,
    P19          IN VARCHAR2    DEFAULT NULL,
    P_MAX_LENGTH IN PLS_INTEGER DEFAULT 1000,
    P_PREFIX     IN VARCHAR2    DEFAULT NULL )
    RETURN VARCHAR2
IS
    L_MESSAGE      VARCHAR2(32767);
    L_RESULT       VARCHAR2(32767);
    L_START        PLS_INTEGER := 1;
    L_CURRENT_ARG  PLS_INTEGER := 1;
    L_FOUND        PLS_INTEGER;
    L_FORMAT_CODE  VARCHAR2(2 CHAR);
    L_FORMAT_CHAR2 VARCHAR2(1 CHAR);
    L_INCREMENT    PLS_INTEGER;

    FUNCTION LIMIT_STRING (
        P_STRING IN VARCHAR2 )
        RETURN VARCHAR2
    IS
        C_LENGTH CONSTANT NUMBER := LENGTH(P_STRING);
    BEGIN
        RETURN CASE
                 WHEN C_LENGTH > P_MAX_LENGTH THEN
                   SUBSTR(P_STRING, 1, P_MAX_LENGTH-1)||'~'
                 WHEN C_LENGTH = P_MAX_LENGTH THEN
                   SUBSTR(P_STRING, 1, P_MAX_LENGTH)
                 ELSE
                   P_STRING
               END;
    END LIMIT_STRING;

BEGIN
    IF P_MESSAGE IS NOT NULL THEN
        IF P_PREFIX IS NULL THEN
            L_MESSAGE := P_MESSAGE;
        ELSE
            L_MESSAGE := REGEXP_REPLACE (
                             SRCSTR     => P_MESSAGE,
                             PATTERN    => '^\s*'||P_PREFIX,
                             REPLACESTR => NULL,
                             MODIFIER   => 'm' );
        END IF;

        LOOP
            
            
            
            L_FOUND := INSTR (
                           L_MESSAGE,
                           '%',
                           L_START );
            IF L_FOUND = 0 THEN
                
                
                
                L_RESULT := L_RESULT ||
                            SUBSTR (
                                L_MESSAGE,
                                L_START );
                EXIT;
            ELSE
                IF L_FOUND > L_START THEN
                    
                    
                    L_RESULT := L_RESULT ||
                                SUBSTR (
                                    L_MESSAGE,
                                    L_START,
                                    L_FOUND-L_START );
                END IF;
                
                
                
                L_FORMAT_CODE := SUBSTR (
                                     L_MESSAGE,
                                     L_FOUND+1,
                                     1 );
                IF L_FORMAT_CODE IN ('s', 'd') THEN
                    
                    
                    
                    
                    
                    
                    PRAGMA INLINE(LIMIT_STRING,'YES');
                    L_RESULT := L_RESULT ||
                                CASE L_CURRENT_ARG
                                  WHEN  1 THEN LIMIT_STRING(P0)
                                  WHEN  2 THEN LIMIT_STRING(P1)
                                  WHEN  3 THEN LIMIT_STRING(P2)
                                  WHEN  4 THEN LIMIT_STRING(P3)
                                  WHEN  5 THEN LIMIT_STRING(P4)
                                  WHEN  6 THEN LIMIT_STRING(P5)
                                  WHEN  7 THEN LIMIT_STRING(P6)
                                  WHEN  8 THEN LIMIT_STRING(P7)
                                  WHEN  9 THEN LIMIT_STRING(P8)
                                  WHEN 10 THEN LIMIT_STRING(P9)
                                  WHEN 11 THEN LIMIT_STRING(P10)
                                  WHEN 12 THEN LIMIT_STRING(P11)
                                  WHEN 13 THEN LIMIT_STRING(P12)
                                  WHEN 14 THEN LIMIT_STRING(P13)
                                  WHEN 15 THEN LIMIT_STRING(P14)
                                  WHEN 16 THEN LIMIT_STRING(P15)
                                  WHEN 17 THEN LIMIT_STRING(P16)
                                  WHEN 18 THEN LIMIT_STRING(P17)
                                  WHEN 19 THEN LIMIT_STRING(P18)
                                  WHEN 20 THEN LIMIT_STRING(P19)
                                END;
                    L_CURRENT_ARG := L_CURRENT_ARG + 1;
                    L_INCREMENT   := 2;
                ELSE
                    
                    
                    
                    
                    IF L_FORMAT_CODE='1' THEN
                        L_FORMAT_CHAR2 := SUBSTR (
                                              L_MESSAGE,
                                              L_FOUND+2,
                                              1 );
                        IF L_FORMAT_CHAR2 BETWEEN '0' AND '9' THEN
                            L_FORMAT_CODE := L_FORMAT_CODE||L_FORMAT_CHAR2;
                            L_INCREMENT := 3;
                        ELSE
                            L_INCREMENT := 2;
                        END IF;
                    ELSE
                        L_INCREMENT := 2;
                    END IF;

                    PRAGMA INLINE(LIMIT_STRING,'YES');
                    L_RESULT := L_RESULT ||
                                CASE L_FORMAT_CODE
                                  WHEN  '0' THEN LIMIT_STRING(P0)
                                  WHEN  '1' THEN LIMIT_STRING(P1)
                                  WHEN  '2' THEN LIMIT_STRING(P2)
                                  WHEN  '3' THEN LIMIT_STRING(P3)
                                  WHEN  '4' THEN LIMIT_STRING(P4)
                                  WHEN  '5' THEN LIMIT_STRING(P5)
                                  WHEN  '6' THEN LIMIT_STRING(P6)
                                  WHEN  '7' THEN LIMIT_STRING(P7)
                                  WHEN  '8' THEN LIMIT_STRING(P8)
                                  WHEN  '9' THEN LIMIT_STRING(P9)
                                  WHEN '10' THEN LIMIT_STRING(P10)
                                  WHEN '11' THEN LIMIT_STRING(P11)
                                  WHEN '12' THEN LIMIT_STRING(P12)
                                  WHEN '13' THEN LIMIT_STRING(P13)
                                  WHEN '14' THEN LIMIT_STRING(P14)
                                  WHEN '15' THEN LIMIT_STRING(P15)
                                  WHEN '16' THEN LIMIT_STRING(P16)
                                  WHEN '17' THEN LIMIT_STRING(P17)
                                  WHEN '18' THEN LIMIT_STRING(P18)
                                  WHEN '19' THEN LIMIT_STRING(P19)
                                  ELSE L_FORMAT_CODE
                                END;
                END IF;
                
                
                
                L_START := L_FOUND+L_INCREMENT;
            END IF;
        END LOOP;
    END IF;
    RETURN L_RESULT;
END FORMAT;

FUNCTION STRINGIFY (
    P_VALUE IN VARCHAR2 )
    RETURN VARCHAR2
IS
BEGIN
    RETURN CASE
             WHEN P_VALUE IS NULL THEN 'null'
             ELSE '"'||JSON(P_VALUE)||'"'
           END;
END STRINGIFY;




FUNCTION STRINGIFY (
    P_VALUE IN NUMBER )
    RETURN VARCHAR2
IS
    L_VALUE VARCHAR2(4000);
BEGIN
    IF P_VALUE IS NULL THEN
        L_VALUE := 'null';
    ELSIF P_VALUE > 0 AND P_VALUE < 1 THEN
        L_VALUE := '0'||TO_CHAR(P_VALUE, 'TM', 'NLS_NUMERIC_CHARACTERS=''.,''');
    ELSIF P_VALUE > -1 AND P_VALUE < 0 THEN
        L_VALUE := '-0'||TO_CHAR(-P_VALUE, 'TM', 'NLS_NUMERIC_CHARACTERS=''.,''');
    ELSE
        L_VALUE := TO_CHAR(P_VALUE, 'TM', 'NLS_NUMERIC_CHARACTERS=''.,''');
    END IF;

    RETURN L_VALUE;
END STRINGIFY;




FUNCTION STRINGIFY (
    P_VALUE          IN DATE,
    P_FORMAT         IN VARCHAR2 DEFAULT C_DATE_ISO8601,
    P_FROM_TIME_ZONE IN VARCHAR2 DEFAULT NULL )
    RETURN VARCHAR2
IS
BEGIN
    RETURN CASE
             WHEN P_VALUE IS NULL THEN 'null'
             ELSE CASE 
                    WHEN P_FROM_TIME_ZONE IS NULL THEN'"'||TO_CHAR(P_VALUE, P_FORMAT)||'"'
                    ELSE '"'||TO_CHAR( FROM_TZ(CAST(P_VALUE AS TIMESTAMP), P_FROM_TIME_ZONE) AT TIME ZONE '00:00', P_FORMAT)||'"'
                  END
           END;
END STRINGIFY;




FUNCTION STRINGIFY (
    P_VALUE          IN TIMESTAMP,
    P_FORMAT         IN VARCHAR2 DEFAULT C_TIMESTAMP_ISO8601_FF,
    P_FROM_TIME_ZONE IN VARCHAR2 DEFAULT NULL )
    RETURN VARCHAR2
IS
BEGIN
    RETURN CASE
             WHEN P_VALUE IS NULL THEN 'null'
             ELSE CASE 
                    WHEN P_FROM_TIME_ZONE IS NULL THEN'"'||TO_CHAR(P_VALUE, P_FORMAT)||'"'
                    ELSE '"'||TO_CHAR( FROM_TZ(P_VALUE, P_FROM_TIME_ZONE) AT TIME ZONE '00:00', P_FORMAT)||'"'
                  END
           END;
END STRINGIFY;




FUNCTION STRINGIFY (
    P_VALUE        IN TIMESTAMP WITH LOCAL TIME ZONE,
    P_FORMAT       IN VARCHAR2                       DEFAULT C_TIMESTAMP_ISO8601_FF_TZR, 
    P_AT_TIME_ZONE IN VARCHAR2                       DEFAULT NULL )
    RETURN VARCHAR2
IS

    L_FORMAT VARCHAR2(255) := CASE WHEN P_FORMAT = C_TIMESTAMP_ISO8601_FF_TZR AND (
                                            P_AT_TIME_ZONE IS NULL OR 
                                            P_AT_TIME_ZONE IN ('00:00', '+00:00', '-00:00', 'UTC' ) ) 
                                   THEN C_TIMESTAMP_ISO8601_FF 
                                   ELSE P_FORMAT 
                              END;
BEGIN
    RETURN CASE
             WHEN P_VALUE IS NULL THEN 'null'
             WHEN INSTR( LOWER( P_FORMAT ), 'tz') > 0 OR P_FORMAT = C_TIMESTAMP_ISO8601_FF_TZR THEN 
                 CASE WHEN P_AT_TIME_ZONE IS NULL 
                     THEN '"'||TO_CHAR(CAST(P_VALUE AS TIMESTAMP WITH TIME ZONE) AT TIME ZONE '00:00', L_FORMAT)||'"'
                     ELSE '"'||TO_CHAR(CAST(P_VALUE AS TIMESTAMP WITH TIME ZONE) AT TIME ZONE P_AT_TIME_ZONE, L_FORMAT)||'"'
                 END
             ELSE '"'||TO_CHAR(P_VALUE, L_FORMAT)||'"'
           END;
END STRINGIFY;




FUNCTION STRINGIFY (
    P_VALUE  IN TIMESTAMP WITH TIME ZONE,
    P_FORMAT IN VARCHAR2    DEFAULT C_TIMESTAMP_ISO8601_FF_TZD )
    RETURN VARCHAR2
IS
BEGIN
    RETURN CASE
             WHEN P_VALUE IS NULL THEN 'null'
             ELSE '"'||TO_CHAR(P_VALUE, P_FORMAT)||'"'
           END;
END STRINGIFY;




FUNCTION STRINGIFY (
    P_VALUE IN BOOLEAN )
    RETURN VARCHAR2
IS
BEGIN
    RETURN CASE P_VALUE
             WHEN TRUE THEN 'true'
             WHEN FALSE THEN 'false'
             ELSE 'null'
           END;
END STRINGIFY;








FUNCTION TOCHAR (
    P_SYMBOL IN T_SYMBOL )
    RETURN VARCHAR2
IS
BEGIN
    RETURN CASE P_SYMBOL
             WHEN C_SY_EOF             THEN '<eof>'
             WHEN C_SY_BEGIN_ARRAY     THEN '['
             WHEN C_SY_BEGIN_OBJECT    THEN '{'
             WHEN C_SY_END_ARRAY       THEN ']'
             WHEN C_SY_END_OBJECT      THEN '}'
             WHEN C_SY_NAME_SEPARATOR  THEN ':'
             WHEN C_SY_VALUE_SEPARATOR THEN ','
             WHEN C_SY_FALSE           THEN 'false'
             WHEN C_SY_TRUE            THEN 'true'
             WHEN C_SY_NULL            THEN 'null'
             WHEN C_SY_NUMBER          THEN '<num>'
             WHEN C_SY_VARCHAR2        THEN '<varchar2>'
           END;
END TOCHAR;


PROCEDURE ERROR (
    P_LEXER   IN T_LEXER,
    P_MESSAGE IN VARCHAR2 )
IS
BEGIN
    RAISE_APPLICATION_ERROR (
        -20987,
        'Error at line '||
        P_LEXER.POS.LINE||
        ', col '||
        P_LEXER.POS.COL||
        ': '||P_MESSAGE );
END ERROR;

FUNCTION TO_MEMBER_NAME (
    P_STRING IN VARCHAR2 )
    RETURN VARCHAR2
IS
BEGIN
    IF LTRIM(TRANSLATE (
           P_STRING,
           'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890',
           '______________________________________________________________' ),
           '_') IS NULL
    THEN
        RETURN P_STRING;
    ELSE
        RETURN '"'||REPLACE(P_STRING, '"', '\"')||'"';
    END IF;
END TO_MEMBER_NAME;


FUNCTION LEX_NEXT (
    P_LEXER IN OUT NOCOPY T_LEXER )
    RETURN T_SYMBOL
IS
    L_SYMBOL T_SYMBOL := C_SY_EOF;
    C        T_CHAR;
    L_ASCII  NUMBER;

    PROCEDURE APPEND_TO_VARCHAR2 (
        P_CHAR IN T_CHAR DEFAULT C )
    IS
    BEGIN
        IF P_LEXER.VARCHAR2_LENGTH > 8190 THEN
            BEGIN
                P_LEXER.VARCHAR2_VALUE := P_LEXER.VARCHAR2_VALUE||P_CHAR;
            EXCEPTION WHEN VALUE_ERROR THEN
                IF P_LEXER.CLOB_WRITER IS NULL THEN
                    P_LEXER.CLOB_WRITER := apx_T_CLOB_WRITER (
                                               P_CACHE => TRUE,
                                               P_DUR   => SYS.DBMS_LOB.CALL );
                END IF;
                P_LEXER.CLOB_WRITER.PRN(P_LEXER.VARCHAR2_VALUE);
                P_LEXER.VARCHAR2_LENGTH := 0;
                P_LEXER.VARCHAR2_VALUE := P_CHAR;
            END;
        ELSE
            P_LEXER.VARCHAR2_VALUE := P_LEXER.VARCHAR2_VALUE||P_CHAR;
        END IF;
        P_LEXER.VARCHAR2_LENGTH := P_LEXER.VARCHAR2_LENGTH + 1;
    END APPEND_TO_VARCHAR2;

    PROCEDURE LEX_NUMBER
    IS
        L_STATE   BINARY_INTEGER NOT NULL := 1;
        L_ISDIGIT BOOLEAN;
    BEGIN



        LOOP
            PRAGMA INLINE(APPEND_TO_VARCHAR2,'YES');
            APPEND_TO_VARCHAR2;
            READ (
                P_THIS => P_LEXER.READER,
                P_CHAR => C );
            L_ASCII := ASCII(C);

            L_ISDIGIT := L_ASCII BETWEEN C_0# AND C_9#;

            IF L_STATE IN (1, 3, 6) AND L_ISDIGIT THEN
                NULL;
            ELSIF L_STATE = 1 AND L_ASCII = C_DOT# THEN
                L_STATE := 2;
            ELSIF L_STATE = 2 AND L_ISDIGIT THEN
                L_STATE := 3;
            ELSIF L_STATE IN (1, 3) AND L_ASCII IN (C_E#, C_UPPER_E#) THEN
                L_STATE := 4;
            ELSIF L_STATE = 4 AND L_ASCII IN (C_MINUS#, C_PLUS#) THEN
                L_STATE := 5;
            ELSIF L_STATE IN (4, 5) AND L_ISDIGIT THEN
                L_STATE := 6;
            ELSIF L_STATE IN (1, 3, 6) THEN
                UNREAD (
                    P_THIS => P_LEXER.READER,
                    P_CHAR => C );
                EXIT;
            ELSE
                ERROR (
                    P_LEXER   => P_LEXER,
                    P_MESSAGE => 'Invalid number: '||P_LEXER.VARCHAR2_VALUE||C );
            END IF;
        END LOOP;

        L_SYMBOL             := C_SY_NUMBER;
        P_LEXER.NUMBER_VALUE := TO_NUMBER(P_LEXER.VARCHAR2_VALUE);
    END LEX_NUMBER;

    PROCEDURE LEX_VARCHAR2
    IS
        L_ESC       BOOLEAN        NOT NULL := FALSE;
        L_HEX       VARCHAR2(10);



        PROCEDURE HANDLE_INCOMPLETE_HEX
        IS
        BEGIN
            IF L_HEX IS NOT NULL THEN
                APPEND_TO_VARCHAR2 (
                    P_CHAR => '\' );
                APPEND_TO_VARCHAR2 (
                    P_CHAR => 'u' );
                FOR I IN 2 .. 5 LOOP
                    APPEND_TO_VARCHAR2 (
                        P_CHAR => SUBSTR(L_HEX, I, 1) );
                END LOOP;
            END IF;
        END HANDLE_INCOMPLETE_HEX;
    BEGIN
        P_LEXER.VARCHAR2_VALUE := NULL;
        C := READ_UNTIL (
                 P_THIS     => P_LEXER.READER,
                 P_CHAR     => '"',
                 P_ESC_CHAR => '\',
                 P_RESULT   => P_LEXER.VARCHAR2_VALUE );
        P_LEXER.VARCHAR2_LENGTH := LENGTH(P_LEXER.VARCHAR2_VALUE);

        LOOP
            IF C IS NULL THEN
                ERROR (
                    P_LEXER   => P_LEXER,
                    P_MESSAGE => 'Unterminated quoted string' );
            END IF;

            L_ASCII := ASCII(C);

            IF L_ESC THEN
                CASE L_ASCII
                WHEN C_DOUBLEQUOTE# THEN NULL;
                WHEN C_BACKSLASH# THEN NULL;
                WHEN C_SLASH# THEN NULL;
                WHEN C_B# THEN C := C_BS;
                WHEN C_F# THEN C := C_FF;
                WHEN C_N# THEN C := C_LF;
                WHEN C_R# THEN C := C_CR;
                WHEN C_T# THEN C := C_TAB;
                WHEN C_U# THEN









                    IF LENGTH(L_HEX) = 5 THEN
                        L_HEX := L_HEX||'\';
                    ELSE
                        L_HEX := '\';
                    END IF;
                    READ (
                        P_THIS => P_LEXER.READER,
                        P_CHAR => C );
                    L_HEX := L_HEX||C;
                    READ (
                        P_THIS => P_LEXER.READER,
                        P_CHAR => C );
                    L_HEX := L_HEX||C;
                    READ (
                        P_THIS => P_LEXER.READER,
                        P_CHAR => C );
                    L_HEX := L_HEX||C;
                    READ (
                        P_THIS => P_LEXER.READER,
                        P_CHAR => C );
                    L_HEX := LOWER(L_HEX||C);
                    IF L_HEX BETWEEN '\d800' AND '\dbff' AND LENGTH(L_HEX) <> 10 THEN




                        C := NULL;
                    ELSE



                        BEGIN
                            C     := UNISTR(L_HEX);
                            L_HEX := NULL;
                        EXCEPTION WHEN OTHERS THEN
                            ERROR (
                                P_LEXER   => P_LEXER,
                                P_MESSAGE => '"'||L_HEX||'" is not a valid hex string' );
                        END;
                    END IF;
                ELSE ERROR (
                         P_LEXER   => P_LEXER,
                         P_MESSAGE => 'Invalid escape sequence \'||C );
                END CASE;

                IF C IS NOT NULL THEN
                    PRAGMA INLINE(HANDLE_INCOMPLETE_HEX,'YES');
                    HANDLE_INCOMPLETE_HEX;
                    PRAGMA INLINE(APPEND_TO_VARCHAR2,'YES');
                    APPEND_TO_VARCHAR2;
                END IF;
                L_ESC := FALSE;
            ELSIF L_ASCII = C_BACKSLASH# THEN
                L_ESC := TRUE;
            ELSIF L_ASCII = C_DOUBLEQUOTE# THEN
                PRAGMA INLINE(HANDLE_INCOMPLETE_HEX,'YES');
                HANDLE_INCOMPLETE_HEX;
                EXIT;
            ELSE
                PRAGMA INLINE(HANDLE_INCOMPLETE_HEX,'YES');
                HANDLE_INCOMPLETE_HEX;
                PRAGMA INLINE(APPEND_TO_VARCHAR2,'YES');
                APPEND_TO_VARCHAR2;
            END IF;
            READ (
                P_THIS => P_LEXER.READER,
                P_CHAR => C );
        END LOOP;

        L_SYMBOL := C_SY_VARCHAR2;
    END LEX_VARCHAR2;

    PROCEDURE LEX_UNQUOTED_VARCHAR2
    IS
    BEGIN
        P_LEXER.VARCHAR2_VALUE  := C;
        P_LEXER.VARCHAR2_LENGTH := 1;
        LOOP
            READ (
                P_THIS => P_LEXER.READER,
                P_CHAR => C );

            L_ASCII := ASCII(C);

            IF L_ASCII BETWEEN C_A# AND C_Z#
               OR L_ASCII BETWEEN C_UPPER_A# AND C_UPPER_Z#
               OR L_ASCII BETWEEN C_0# AND C_9#
               OR L_ASCII = C_UNDERSCORE#
            THEN
                PRAGMA INLINE(APPEND_TO_VARCHAR2,'YES');
                APPEND_TO_VARCHAR2;
            ELSE
                IF L_ASCII NOT IN (C_SPACE#, C_TAB#, C_LF#, C_CR#) THEN
                    UNREAD (
                        P_THIS => P_LEXER.READER,
                        P_CHAR => C );
                END IF;
                EXIT;
            END IF;
        END LOOP;

        IF P_LEXER.VARCHAR2_VALUE = 'null' THEN
            L_SYMBOL := C_SY_NULL;
        ELSIF P_LEXER.VARCHAR2_VALUE = 'true' THEN
            L_SYMBOL := C_SY_TRUE;
        ELSIF P_LEXER.VARCHAR2_VALUE = 'false' THEN
            L_SYMBOL := C_SY_FALSE;
        ELSE
            IF P_LEXER.IS_STRICT THEN
                ERROR (
                    P_LEXER   => P_LEXER,
                    P_MESSAGE => 'strict mode JSON parser does not allow unquoted literals' );
            ELSE
                L_SYMBOL                         := C_SY_VARCHAR2;
            END IF;
        END IF;
    END LEX_UNQUOTED_VARCHAR2;

BEGIN
    READ_NON_WS (
        P_THIS => P_LEXER.READER,
        P_CHAR => C );

    IF C IS NULL THEN
        RETURN C_SY_EOF;
    END IF;

    L_ASCII                 := ASCII(C);
    P_LEXER.POS             := P_LEXER.READER.POS;
    P_LEXER.NUMBER_VALUE    := NULL;
    P_LEXER.VARCHAR2_VALUE  := NULL;
    P_LEXER.VARCHAR2_LENGTH := 0;

    IF L_ASCII = C_BRACKET_OPEN# THEN
        L_SYMBOL := C_SY_BEGIN_ARRAY;
    ELSIF L_ASCII = C_CBRACE_OPEN# THEN
        L_SYMBOL := C_SY_BEGIN_OBJECT;
    ELSIF L_ASCII = C_BRACKET_CLOSE# THEN
        L_SYMBOL := C_SY_END_ARRAY;
    ELSIF L_ASCII = C_CBRACE_CLOSE# THEN
        L_SYMBOL := C_SY_END_OBJECT;
    ELSIF L_ASCII = C_COLON# THEN
        L_SYMBOL := C_SY_NAME_SEPARATOR;
    ELSIF L_ASCII = C_COMMA# THEN
        L_SYMBOL := C_SY_VALUE_SEPARATOR;
    ELSIF L_ASCII = C_MINUS# THEN
        P_LEXER.VARCHAR2_VALUE  := C;
        P_LEXER.VARCHAR2_LENGTH := 1;
        READ_NON_WS (
            P_THIS => P_LEXER.READER,
            P_CHAR => C );
        L_ASCII := ASCII(C);
        IF L_ASCII BETWEEN C_0# AND C_9# THEN
            PRAGMA INLINE(LEX_NUMBER, 'YES');
            LEX_NUMBER;
        ELSE
            ERROR (
                P_LEXER   => P_LEXER,
                P_MESSAGE => 'expected 0-9 after minus sign, not "'||C||'"' );
        END IF;
    ELSIF L_ASCII BETWEEN C_0# AND C_9# THEN
        PRAGMA INLINE(LEX_NUMBER, 'YES');
        LEX_NUMBER;
    ELSIF L_ASCII = C_DOUBLEQUOTE# THEN
        PRAGMA INLINE(LEX_VARCHAR2, 'YES');
        LEX_VARCHAR2;
    ELSIF L_ASCII BETWEEN C_A# AND C_Z#
          OR L_ASCII BETWEEN C_UPPER_A# AND C_UPPER_Z#
          OR L_ASCII = C_UNDERSCORE#
    THEN
        PRAGMA INLINE(LEX_UNQUOTED_VARCHAR2, 'YES');
        LEX_UNQUOTED_VARCHAR2;
    ELSE
        ERROR (
            P_LEXER   => P_LEXER,
            P_MESSAGE => 'Unexpected character "'||C||'"' );
    END IF;









    RETURN L_SYMBOL;
END LEX_NEXT;



PROCEDURE DO_PARSE (
    P_LEXER      IN OUT NOCOPY T_LEXER,
    P_NAME       IN VARCHAR2,
    P_VALUES     IN OUT NOCOPY T_VALUES,
    P_XML_WRITER IN OUT NOCOPY apx_T_CLOB_WRITER )
IS
    L_SYMBOL T_SYMBOL := LEX_NEXT(P_LEXER => P_LEXER); 


    PROCEDURE LEX_EAT (
        P_SYMBOL IN T_SYMBOL )
    IS
    BEGIN
        IF L_SYMBOL <> P_SYMBOL THEN
            ERROR (
                P_LEXER   => P_LEXER,
                P_MESSAGE => 'Expected "'||TOCHAR(P_SYMBOL)||
                             '", seeing "'||TOCHAR(L_SYMBOL)||
                             '"' );
        END IF;
        L_SYMBOL := LEX_NEXT(P_LEXER => P_LEXER);
    END LEX_EAT;


    PROCEDURE DO_ARRAY (
        P_NAME IN VARCHAR2 );


    PROCEDURE DO_OBJECT (
        P_NAME IN VARCHAR2 );


    PROCEDURE WRITE_XML_VALUE (
        P_VALUE   IN VARCHAR2,
        P_XML_TAG IN VARCHAR2 )
    IS
        C_VALUE_LENGTH CONSTANT PLS_INTEGER := LENGTH(P_VALUE);
        I              PLS_INTEGER;
    BEGIN



        IF P_XML_TAG IS NOT NULL THEN
            P_XML_WRITER.PRN('<'||P_XML_TAG||'>');
        END IF;




        IF C_VALUE_LENGTH <= 4000 THEN
            P_XML_WRITER.PRN(HTML(P_VALUE));
        ELSE
            I := 1;
            WHILE I <= C_VALUE_LENGTH LOOP
                P_XML_WRITER.PRN(HTML(SUBSTR(P_VALUE, I, 4000)));
                I := I + 4000;
            END LOOP;
        END IF;



        IF P_XML_TAG IS NOT NULL THEN
            P_XML_WRITER.P('</'||P_XML_TAG||'>');
        END IF;
    END WRITE_XML_VALUE;


    PROCEDURE WRITE_XML_VALUE (
        P_VALUE   IN CLOB,
        P_XML_TAG IN VARCHAR2 )
    IS
        L_CHUNK  VARCHAR2(32767);
        L_OFFSET PLS_INTEGER;
    BEGIN



        IF P_XML_TAG IS NOT NULL THEN
            P_XML_WRITER.PRN('<'||P_XML_TAG||'>');
        END IF;




        WHILE NEXT_CHUNK (
                  P_STR    => P_VALUE,
                  P_CHUNK  => L_CHUNK,
                  P_OFFSET => L_OFFSET,
                  P_AMOUNT => 4000 )
        LOOP
            P_XML_WRITER.PRN(HTML(L_CHUNK));
        END LOOP;



        IF P_XML_TAG IS NOT NULL THEN
            P_XML_WRITER.P('</'||P_XML_TAG||'>');
        END IF;
    END WRITE_XML_VALUE;


    FUNCTION FIX_XML_NAME (
        P_NAME IN VARCHAR2 )
        RETURN VARCHAR2
    IS
        L_NAME VARCHAR2(32767);
    BEGIN
        IF P_NAME LIKE '-%' THEN
            L_NAME := '_'||SUBSTR(P_NAME, 2);
        ELSE
            L_NAME := P_NAME;
        END IF;

        RETURN REGEXP_REPLACE (
                   L_NAME,
                   '[^[:alnum:]_-]',
                   '_' );
    END FIX_XML_NAME;


    PROCEDURE DO_VALUE (
        P_NAME    IN VARCHAR2,
        P_XML_TAG IN VARCHAR2 )
    IS
        L_VALUE  T_VALUE;
    BEGIN


        CASE L_SYMBOL
        WHEN C_SY_BEGIN_ARRAY THEN
            IF P_XML_WRITER IS NOT NULL AND P_XML_TAG IS NOT NULL THEN
                P_XML_WRITER.PRN('<'||P_XML_TAG||'>');
            END IF;
            DO_ARRAY (
                P_NAME => P_NAME );
            IF P_XML_WRITER IS NOT NULL AND P_XML_TAG IS NOT NULL THEN
                P_XML_WRITER.P('</'||P_XML_TAG||'>');
            END IF;
        WHEN C_SY_BEGIN_OBJECT THEN
            IF P_XML_WRITER IS NOT NULL AND P_XML_TAG IS NOT NULL THEN
                P_XML_WRITER.PRN('<'||P_XML_TAG||'>');
            END IF;
            DO_OBJECT (
                P_NAME => P_NAME );
            IF P_XML_WRITER IS NOT NULL AND P_XML_TAG IS NOT NULL THEN
                P_XML_WRITER.P('</'||P_XML_TAG||'>');
            END IF;
        WHEN C_SY_FALSE THEN
            IF P_XML_WRITER IS NOT NULL THEN
                PRAGMA INLINE(WRITE_XML_VALUE, 'YES');
                WRITE_XML_VALUE (
                    P_VALUE   => 'false',
                    P_XML_TAG => P_XML_TAG );
            ELSE
                L_VALUE.KIND      := C_FALSE;
                P_VALUES(P_NAME)  := L_VALUE;
            END IF;
            L_SYMBOL := LEX_NEXT(P_LEXER => P_LEXER);
        WHEN C_SY_TRUE THEN
            IF P_XML_WRITER IS NOT NULL THEN
                PRAGMA INLINE(WRITE_XML_VALUE, 'YES');
                WRITE_XML_VALUE (
                    P_VALUE   => 'true',
                    P_XML_TAG => P_XML_TAG );
            ELSE
                L_VALUE.KIND      := C_TRUE;
                P_VALUES(P_NAME)  := L_VALUE;
            END IF;
            L_SYMBOL := LEX_NEXT(P_LEXER => P_LEXER);
        WHEN C_SY_NULL THEN
            IF P_XML_WRITER IS NOT NULL THEN
                NULL;
            ELSE
                L_VALUE.KIND      := C_NULL;
                P_VALUES(P_NAME)  := L_VALUE;
            END IF;
            L_SYMBOL := LEX_NEXT(P_LEXER => P_LEXER);
        WHEN C_SY_NUMBER THEN
            IF P_XML_WRITER IS NOT NULL THEN
                PRAGMA INLINE(WRITE_XML_VALUE, 'YES');
                WRITE_XML_VALUE (
                    P_VALUE   => NULLIF (
                                     STRINGIFY(P_LEXER.NUMBER_VALUE),
                                     'null' ),
                    P_XML_TAG => P_XML_TAG );
            ELSE
                L_VALUE.KIND      := C_NUMBER;
                L_VALUE.NUMBER_VALUE := P_LEXER.NUMBER_VALUE;
                P_VALUES(P_NAME)  := L_VALUE;
            END IF;
            L_SYMBOL := LEX_NEXT(P_LEXER => P_LEXER);
        WHEN C_SY_VARCHAR2 THEN
            IF P_LEXER.CLOB_WRITER IS NOT NULL THEN
                P_LEXER.CLOB_WRITER.PRN(P_LEXER.VARCHAR2_VALUE);
            END IF;
            IF P_XML_WRITER IS NOT NULL THEN
                IF P_LEXER.CLOB_WRITER IS NOT NULL THEN
                    PRAGMA INLINE(WRITE_XML_VALUE, 'YES');
                    WRITE_XML_VALUE (
                        P_VALUE   => P_LEXER.CLOB_WRITER.GET_VALUE,
                        P_XML_TAG => P_XML_TAG );
                    P_LEXER.CLOB_WRITER := NULL;
                ELSE
                    PRAGMA INLINE(WRITE_XML_VALUE, 'YES');
                    WRITE_XML_VALUE (
                        P_VALUE   => P_LEXER.VARCHAR2_VALUE,
                        P_XML_TAG => P_XML_TAG );
                END IF;
            ELSE
                IF P_LEXER.CLOB_WRITER IS NOT NULL THEN
                    L_VALUE.KIND        := C_CLOB;
                    L_VALUE.CLOB_VALUE  := P_LEXER.CLOB_WRITER.GET_VALUE;
                    P_VALUES(P_NAME)    := L_VALUE;
                    P_LEXER.CLOB_WRITER := NULL;
                ELSE
                    L_VALUE.KIND           := C_VARCHAR2;
                    L_VALUE.VARCHAR2_VALUE := P_LEXER.VARCHAR2_VALUE;
                    P_VALUES(P_NAME)       := L_VALUE;
                END IF;
            END IF;
            L_SYMBOL := LEX_NEXT(P_LEXER => P_LEXER);
        ELSE
            ERROR (
                P_LEXER   => P_LEXER,
                P_MESSAGE => 'Expected value (null, false, true, number, varchar2)' );
        END CASE;
    END DO_VALUE;



    PROCEDURE DO_ARRAY (
        P_NAME IN VARCHAR2 )
    IS
        L_INDEX        BINARY_INTEGER NOT NULL := 0;
        L_BASE VARCHAR2(32767)                 := P_NAME || '[';
        L_ARRAY_VALUE  T_VALUE;
    BEGIN

        PRAGMA INLINE(LEX_EAT, 'YES');
        LEX_EAT(C_SY_BEGIN_ARRAY);

        L_ARRAY_VALUE.KIND := C_ARRAY;

        IF L_SYMBOL <> C_SY_END_ARRAY THEN
            L_INDEX := 1;
            DO_VALUE (
                P_NAME    => L_BASE || L_INDEX || ']',
                P_XML_TAG => 'row' );
            WHILE L_SYMBOL = C_SY_VALUE_SEPARATOR LOOP
                PRAGMA INLINE(LEX_EAT, 'YES');
                LEX_EAT(C_SY_VALUE_SEPARATOR);

                IF L_SYMBOL = C_SY_END_ARRAY THEN
                    IF P_LEXER.IS_STRICT THEN
                        ERROR (
                            P_LEXER   => P_LEXER,
                            P_MESSAGE => 'Strict JSON forbids dangling comma' );
                    ELSE
                        EXIT;
                    END IF;
                END IF;

                L_INDEX  := L_INDEX + 1;
                DO_VALUE (
                    P_NAME    => L_BASE || L_INDEX || ']',
                    P_XML_TAG => 'row' );
            END LOOP;
        END IF;

        L_ARRAY_VALUE.NUMBER_VALUE := L_INDEX;
        P_VALUES(NVL(P_NAME,'.'))  := L_ARRAY_VALUE;

        PRAGMA INLINE(LEX_EAT, 'YES');
        LEX_EAT(C_SY_END_ARRAY);
    END DO_ARRAY;



    PROCEDURE DO_OBJECT (
        P_NAME IN VARCHAR2 )
    IS
        L_BASE           VARCHAR2(32767) := P_NAME ||
                                          CASE WHEN P_NAME  IS NOT NULL THEN '.' END;
        L_IS_SIMPLE_NAME BOOLEAN;
        L_SIMPLE_NAME    VARCHAR2(32767);
        L_NAME           VARCHAR2(32767);
        L_OBJECT_VALUE   T_VALUE;
        L_MEMBER_COUNT   PLS_INTEGER NOT NULL := 0;
        PROCEDURE DO_NAME_VALUE
        IS
        BEGIN
            IF L_SYMBOL = C_SY_VARCHAR2 THEN
                L_SIMPLE_NAME := P_LEXER.VARCHAR2_VALUE;

                PRAGMA INLINE(TO_MEMBER_NAME, 'YES');
                L_NAME        := TO_MEMBER_NAME(L_SIMPLE_NAME);
                L_SYMBOL := LEX_NEXT(P_LEXER => P_LEXER);

                PRAGMA INLINE(LEX_EAT, 'YES');
                LEX_EAT(C_SY_NAME_SEPARATOR);

                IF P_XML_WRITER IS NULL OR L_SIMPLE_NAME = L_NAME THEN
                    DO_VALUE (
                        P_NAME    => L_BASE||L_NAME,
                        P_XML_TAG => L_SIMPLE_NAME );
                ELSE
                    PRAGMA INLINE(FIX_XML_NAME, 'YES');
                    DO_VALUE (
                        P_NAME    => L_BASE||L_NAME,
                        P_XML_TAG => FIX_XML_NAME(L_SIMPLE_NAME));
                END IF;

                L_MEMBER_COUNT := L_MEMBER_COUNT+1;
                L_OBJECT_VALUE.OBJECT_MEMBERS.EXTEND;
                L_OBJECT_VALUE.OBJECT_MEMBERS(L_MEMBER_COUNT) := L_NAME;
            ELSE
                ERROR (
                    P_LEXER   => P_LEXER,
                    P_MESSAGE => 'Expected varchar2 (object member name)' );
            END IF;
        END DO_NAME_VALUE;
    BEGIN
        L_OBJECT_VALUE.KIND           := C_OBJECT;
        L_OBJECT_VALUE.OBJECT_MEMBERS := apx_T_VARCHAR2();


        PRAGMA INLINE(LEX_EAT, 'YES');
        LEX_EAT(C_SY_BEGIN_OBJECT);

        IF L_SYMBOL <> C_SY_END_OBJECT THEN
            PRAGMA INLINE(DO_NAME_VALUE, 'YES');
            DO_NAME_VALUE;

            WHILE L_SYMBOL = C_SY_VALUE_SEPARATOR LOOP
                PRAGMA INLINE(LEX_EAT, 'YES');
                LEX_EAT(C_SY_VALUE_SEPARATOR);
                IF L_SYMBOL = C_SY_END_OBJECT THEN
                    IF P_LEXER.IS_STRICT THEN
                        ERROR (
                            P_LEXER   => P_LEXER,
                            P_MESSAGE => 'Strict JSON forbids dangling comma' );
                    ELSE
                        EXIT;
                    END IF;
                END IF;

                PRAGMA INLINE(DO_NAME_VALUE, 'YES');
                DO_NAME_VALUE;
            END LOOP;
        END IF;

        PRAGMA INLINE(LEX_EAT, 'YES');
        LEX_EAT(C_SY_END_OBJECT);

        P_VALUES(NVL(P_NAME,'.')) := L_OBJECT_VALUE;
    END DO_OBJECT;

    PROCEDURE RESET_NLS (
        P_CHARS IN VARCHAR2 DEFAULT P_LEXER.PREV_NUMERIC_CHARS )
    IS
    BEGIN
        IF P_LEXER.PREV_NUMERIC_CHARS <> '.,' THEN
            EXECUTE IMMEDIATE 'alter session set nls_numeric_characters='||
                              ENQUOTE_LITERAL(P_CHARS);
        END IF;
    END RESET_NLS;

BEGIN
    SELECT VALUE
      INTO P_LEXER.PREV_NUMERIC_CHARS
      FROM SYS.NLS_SESSION_PARAMETERS
     WHERE PARAMETER = 'NLS_NUMERIC_CHARACTERS';
    RESET_NLS (
        P_CHARS => '.,' );

    IF L_SYMBOL = C_SY_BEGIN_ARRAY THEN
        IF P_XML_WRITER IS NOT NULL THEN
            P_XML_WRITER.PRN('<json>');
        END IF;
        DO_ARRAY (
            P_NAME => NULL );
        LEX_EAT(C_SY_EOF);
        IF P_XML_WRITER IS NOT NULL THEN
            P_XML_WRITER.PRN('</json>');
        END IF;
    ELSIF L_SYMBOL = C_SY_BEGIN_OBJECT THEN
        IF P_XML_WRITER IS NOT NULL THEN
            P_XML_WRITER.PRN('<json>');
        END IF;
        DO_OBJECT (
            P_NAME => NULL );
        LEX_EAT(C_SY_EOF);
        IF P_XML_WRITER IS NOT NULL THEN
            P_XML_WRITER.PRN('</json>');
        END IF;
    ELSIF L_SYMBOL = C_SY_EOF THEN
        NULL;
    ELSE
        ERROR (
            P_LEXER   => P_LEXER,
            P_MESSAGE => 'expected [ or {' );
    END IF;

    RESET_NLS;
EXCEPTION WHEN OTHERS THEN
    RESET_NLS;
    RAISE;
END DO_PARSE;


PROCEDURE PARSE (
    P_VALUES   IN OUT NOCOPY T_VALUES,
    P_SOURCE   IN VARCHAR2,
    P_STRICT   IN BOOLEAN DEFAULT TRUE )
IS
    L_LEXER T_LEXER;
BEGIN
    P_VALUES.DELETE;

    L_LEXER.IS_STRICT                := P_STRICT;
    L_LEXER.READER.IS_LINE_SEPARATED := FALSE;
    L_LEXER.READER.INPUT(1)          := P_SOURCE;

    DO_PARSE (
        P_LEXER      => L_LEXER,
        P_VALUES     => P_VALUES,
        P_NAME       => NULL,
        P_XML_WRITER => G_NULL_XML_WRITER );
END PARSE;


PROCEDURE PARSE (
    P_SOURCE   IN VARCHAR2,
    P_STRICT   IN BOOLEAN DEFAULT TRUE )
IS
BEGIN
    PARSE (
        P_VALUES => G_VALUES,
        P_SOURCE => P_SOURCE,
        P_STRICT => P_STRICT );
END PARSE;


PROCEDURE PARSE (
    P_VALUES   IN OUT NOCOPY T_VALUES,
    P_SOURCE   IN CLOB,
    P_STRICT   IN BOOLEAN DEFAULT TRUE )
IS
    L_OFFSET PLS_INTEGER;
    L_INDEX  PLS_INTEGER := 1;
    L_LEXER  T_LEXER;
BEGIN
    P_VALUES.DELETE;

    L_LEXER.IS_STRICT                := P_STRICT;
    L_LEXER.READER.IS_LINE_SEPARATED := FALSE;

    WHILE NEXT_CHUNK (
              P_STR    => P_SOURCE,
              P_CHUNK  => L_LEXER.READER.INPUT(L_INDEX),
              P_OFFSET => L_OFFSET )
    LOOP
        L_INDEX := L_INDEX + 1;
    END LOOP;

    DO_PARSE (
        P_LEXER      => L_LEXER,
        P_VALUES     => P_VALUES,
        P_NAME       => NULL,
        P_XML_WRITER => G_NULL_XML_WRITER );
END PARSE;


PROCEDURE PARSE (
    P_VALUES   IN OUT NOCOPY T_VALUES,
    P_SOURCE   IN VC_ARR2,
    P_STRICT   IN BOOLEAN DEFAULT TRUE )
IS
    L_LEXER T_LEXER;
BEGIN
    P_VALUES.DELETE;

    L_LEXER.IS_STRICT                := P_STRICT;
    L_LEXER.READER.IS_LINE_SEPARATED := FALSE;
    L_LEXER.READER.INPUT             := P_SOURCE;

    DO_PARSE (
        P_LEXER      => L_LEXER,
        P_VALUES     => P_VALUES,
        P_NAME       => NULL,
        P_XML_WRITER => G_NULL_XML_WRITER );
END PARSE;


PROCEDURE PARSE (
    P_SOURCE   IN CLOB,
    P_STRICT   IN BOOLEAN DEFAULT TRUE )
IS
BEGIN
    PARSE (
        P_VALUES => G_VALUES,
        P_SOURCE => P_SOURCE,
        P_STRICT => P_STRICT );
END PARSE;

PROCEDURE PARSE (
    P_SOURCE   IN VC_ARR2,
    P_STRICT   IN BOOLEAN DEFAULT TRUE )
IS
BEGIN
    PARSE (
        P_VALUES => G_VALUES,
        P_SOURCE => P_SOURCE,
        P_STRICT => P_STRICT );
END PARSE;

FUNCTION GET_DB_CHARSET RETURN VARCHAR2
IS
BEGIN
    IF G_DB_CHARSET IS NULL THEN
        
        
        
        FOR C1 IN (SELECT   VALUE
                     FROM SYS.NLS_DATABASE_PARAMETERS
                    WHERE PARAMETER = 'NLS_CHARACTERSET') LOOP
            G_DB_CHARSET := C1.VALUE;
            EXIT;
        END LOOP;
    END IF;
    
    RETURN G_DB_CHARSET;
END GET_DB_CHARSET;

PROCEDURE WRITE_XML_PROLOG (
    P_WRITER IN OUT NOCOPY apx_T_CLOB_WRITER )
IS
    C_ENCODING CONSTANT VARCHAR2(4000) := SYS.UTL_I18N.MAP_CHARSET (
                                              CHARSET => GET_DB_CHARSET );

BEGIN
    P_WRITER.P('<?xml version="1.0" encoding="'||C_ENCODING||'"?>');
END WRITE_XML_PROLOG;


FUNCTION TO_XMLTYPE (
    P_SOURCE   IN VARCHAR2,
    P_STRICT   IN BOOLEAN DEFAULT TRUE )
    RETURN SYS.XMLTYPE
IS
    L_LEXER T_LEXER;
    L_WRITER apx_T_CLOB_WRITER := apx_T_CLOB_WRITER(P_CACHE => TRUE);
    L_VALUES T_VALUES;
BEGIN
    L_LEXER.IS_STRICT                := P_STRICT;
    L_LEXER.READER.IS_LINE_SEPARATED := FALSE;
    L_LEXER.READER.INPUT(1)          := P_SOURCE;

    WRITE_XML_PROLOG (
        P_WRITER => L_WRITER );

    DO_PARSE (
        P_LEXER      => L_LEXER,
        P_VALUES     => L_VALUES,
        P_NAME       => NULL,
        P_XML_WRITER => L_WRITER );

    L_WRITER.FLUSH;
    RETURN SYS.XMLTYPE(L_WRITER.L_CLOB);
END TO_XMLTYPE;


FUNCTION TO_XMLTYPE (
    P_SOURCE   IN CLOB,
    P_STRICT   IN BOOLEAN DEFAULT TRUE )
    RETURN SYS.XMLTYPE
IS
    L_START  PLS_INTEGER NOT NULL := 1;
    L_INDEX  PLS_INTEGER NOT NULL := 1;
    C_LENGTH CONSTANT PLS_INTEGER NOT NULL := CASE
                                                WHEN P_SOURCE IS NULL THEN 0
                                                ELSE SYS.DBMS_LOB.GETLENGTH(P_SOURCE)
                                              END;
    L_LEXER T_LEXER;
    L_WRITER apx_T_CLOB_WRITER := apx_T_CLOB_WRITER(P_CACHE => TRUE);
    L_VALUES T_VALUES;
BEGIN
    L_LEXER.IS_STRICT                := P_STRICT;
    L_LEXER.READER.IS_LINE_SEPARATED := FALSE;

    WHILE L_START <= C_LENGTH LOOP
        L_LEXER.READER.INPUT(L_INDEX) := SYS.DBMS_LOB.SUBSTR (
                                             P_SOURCE,
                                             8191,
                                             L_START );
        L_START := L_START + 8191;
        L_INDEX := L_INDEX + 1;
    END LOOP;

    WRITE_XML_PROLOG (
        P_WRITER => L_WRITER );

    DO_PARSE (
        P_LEXER      => L_LEXER,
        P_VALUES     => L_VALUES,
        P_NAME       => NULL,
        P_XML_WRITER => L_WRITER );

    L_WRITER.FLUSH;
    RETURN SYS.XMLTYPE(L_WRITER.L_CLOB);
END TO_XMLTYPE;


FUNCTION TO_XMLTYPE (
    P_SOURCE   IN VC_ARR2,
    P_STRICT   IN BOOLEAN DEFAULT TRUE )
    RETURN SYS.XMLTYPE
IS
    L_LEXER T_LEXER;
    L_WRITER apx_T_CLOB_WRITER := apx_T_CLOB_WRITER(P_CACHE => TRUE);
    L_VALUES T_VALUES;
BEGIN
    L_LEXER.IS_STRICT                := P_STRICT;
    L_LEXER.READER.IS_LINE_SEPARATED := FALSE;
    L_LEXER.READER.INPUT             := P_SOURCE;

    WRITE_XML_PROLOG (
        P_WRITER => L_WRITER );

    DO_PARSE (
        P_LEXER      => L_LEXER,
        P_VALUES     => L_VALUES,
        P_NAME       => NULL,
        P_XML_WRITER => L_WRITER );

    L_WRITER.FLUSH;
    RETURN SYS.XMLTYPE(L_WRITER.L_CLOB);
END TO_XMLTYPE;


FUNCTION TO_XMLTYPE_SQL (
    P_SOURCE   IN VARCHAR2,
    P_STRICT   IN VARCHAR2 DEFAULT 'Y' )
    RETURN SYS.XMLTYPE IS
BEGIN
    RETURN TO_XMLTYPE( P_SOURCE => P_SOURCE, P_STRICT => ( P_STRICT = 'Y' ) );
END TO_XMLTYPE_SQL;


FUNCTION TO_XMLTYPE_SQL (
    P_SOURCE   IN CLOB,
    P_STRICT   IN VARCHAR2 DEFAULT 'Y' )
    RETURN SYS.XMLTYPE IS
BEGIN
    RETURN TO_XMLTYPE( P_SOURCE => P_SOURCE, P_STRICT => ( P_STRICT = 'Y' ) );
END TO_XMLTYPE_SQL;


FUNCTION DOES_EXIST (
    P_PATH             IN VARCHAR2,
    P0                 IN VARCHAR2 DEFAULT NULL,
    P1                 IN VARCHAR2 DEFAULT NULL,
    P2                 IN VARCHAR2 DEFAULT NULL,
    P3                 IN VARCHAR2 DEFAULT NULL,
    P4                 IN VARCHAR2 DEFAULT NULL,
    P_VALUES           IN T_VALUES DEFAULT G_VALUES )
    RETURN BOOLEAN
IS
BEGIN
    RETURN CASE
             WHEN P0 IS NULL THEN P_VALUES.EXISTS(P_PATH)
             ELSE P_VALUES.EXISTS(FORMAT(P_PATH, P0, P1, P2, P3, P4))
           END;
END DOES_EXIST;


FUNCTION GET_BOOLEAN (
    P_PATH             IN VARCHAR2,
    P0                 IN VARCHAR2 DEFAULT NULL,
    P1                 IN VARCHAR2 DEFAULT NULL,
    P2                 IN VARCHAR2 DEFAULT NULL,
    P3                 IN VARCHAR2 DEFAULT NULL,
    P4                 IN VARCHAR2 DEFAULT NULL,
    P_DEFAULT          IN BOOLEAN  DEFAULT NULL,
    P_VALUES           IN T_VALUES DEFAULT G_VALUES )
    RETURN BOOLEAN
IS
    L_VALUE T_VALUE;
BEGIN
    IF P0 IS NULL THEN
        L_VALUE := P_VALUES(P_PATH);
    ELSE
        L_VALUE := P_VALUES(FORMAT(P_PATH, P0, P1, P2, P3, P4));
    END IF;

    CASE L_VALUE.KIND
      WHEN C_NULL    THEN RETURN NULL;
      WHEN C_TRUE    THEN RETURN TRUE;
      WHEN C_FALSE   THEN RETURN FALSE;
      ELSE                RAISE VALUE_ERROR;
    END CASE;
EXCEPTION WHEN NO_DATA_FOUND THEN RETURN P_DEFAULT;
END GET_BOOLEAN;


FUNCTION T_VALUE_TO_NUMBER (
    P_VALUE IN T_VALUE )
    RETURN NUMBER
IS
BEGIN
    CASE P_VALUE.KIND
      WHEN C_NULL     THEN RETURN NULL;
      WHEN C_NUMBER   THEN RETURN P_VALUE.NUMBER_VALUE;
      WHEN C_VARCHAR2 THEN RETURN TO_NUMBER(P_VALUE.VARCHAR2_VALUE);
      ELSE                 RAISE VALUE_ERROR;
    END CASE;
END T_VALUE_TO_NUMBER;


FUNCTION GET_NUMBER (
    P_PATH             IN VARCHAR2,
    P0                 IN VARCHAR2 DEFAULT NULL,
    P1                 IN VARCHAR2 DEFAULT NULL,
    P2                 IN VARCHAR2 DEFAULT NULL,
    P3                 IN VARCHAR2 DEFAULT NULL,
    P4                 IN VARCHAR2 DEFAULT NULL,
    P_DEFAULT          IN NUMBER   DEFAULT NULL,
    P_VALUES           IN T_VALUES DEFAULT G_VALUES )
    RETURN NUMBER
IS
    L_VALUE T_VALUE;
BEGIN
    IF P0 IS NULL THEN
        L_VALUE := P_VALUES(P_PATH);
    ELSE
        L_VALUE := P_VALUES(FORMAT(P_PATH, P0, P1, P2, P3, P4));
    END IF;

    PRAGMA INLINE(T_VALUE_TO_NUMBER, 'YES');
    RETURN T_VALUE_TO_NUMBER(L_VALUE);
EXCEPTION WHEN NO_DATA_FOUND THEN RETURN P_DEFAULT;
END GET_NUMBER;


FUNCTION T_VALUE_TO_CHAR (
    P_VALUE IN T_VALUE )
    RETURN VARCHAR2
IS
BEGIN
    CASE P_VALUE.KIND
      WHEN C_NULL     THEN RETURN NULL;
      WHEN C_TRUE     THEN RETURN 'true';
      WHEN C_FALSE    THEN RETURN 'false';
      WHEN C_NUMBER   THEN RETURN P_VALUE.NUMBER_VALUE;
      WHEN C_VARCHAR2 THEN RETURN P_VALUE.VARCHAR2_VALUE;
      ELSE                 RAISE VALUE_ERROR;
    END CASE;
END T_VALUE_TO_CHAR;


FUNCTION GET_VARCHAR2 (
    P_PATH             IN VARCHAR2,
    P0                 IN VARCHAR2 DEFAULT NULL,
    P1                 IN VARCHAR2 DEFAULT NULL,
    P2                 IN VARCHAR2 DEFAULT NULL,
    P3                 IN VARCHAR2 DEFAULT NULL,
    P4                 IN VARCHAR2 DEFAULT NULL,
    P_DEFAULT          IN VARCHAR2 DEFAULT NULL,
    P_VALUES           IN T_VALUES DEFAULT G_VALUES )
    RETURN VARCHAR2
IS
    L_VALUE T_VALUE;
BEGIN
    IF P0 IS NULL THEN
        L_VALUE := P_VALUES(P_PATH);
    ELSE
        L_VALUE := P_VALUES(FORMAT(P_PATH, P0, P1, P2, P3, P4));
    END IF;

    PRAGMA INLINE(T_VALUE_TO_CHAR, 'YES');
    RETURN T_VALUE_TO_CHAR(L_VALUE);
EXCEPTION WHEN NO_DATA_FOUND THEN RETURN P_DEFAULT;
END GET_VARCHAR2;


FUNCTION GET_CLOB (
    P_PATH             IN VARCHAR2,
    P0                 IN VARCHAR2 DEFAULT NULL,
    P1                 IN VARCHAR2 DEFAULT NULL,
    P2                 IN VARCHAR2 DEFAULT NULL,
    P3                 IN VARCHAR2 DEFAULT NULL,
    P4                 IN VARCHAR2 DEFAULT NULL,
    P_DEFAULT          IN CLOB     DEFAULT NULL,
    P_VALUES           IN T_VALUES DEFAULT G_VALUES )
    RETURN CLOB
IS
    L_VALUE T_VALUE;
BEGIN
    IF P0 IS NULL THEN
        L_VALUE := P_VALUES(P_PATH);
    ELSE
        L_VALUE := P_VALUES(FORMAT(P_PATH, P0, P1, P2, P3, P4));
    END IF;

    CASE L_VALUE.KIND
      WHEN C_NULL     THEN RETURN NULL;
      WHEN C_TRUE     THEN RETURN 'true';
      WHEN C_FALSE    THEN RETURN 'false';
      WHEN C_NUMBER   THEN RETURN TO_CLOB(L_VALUE.NUMBER_VALUE);
      WHEN C_VARCHAR2 THEN RETURN L_VALUE.VARCHAR2_VALUE;
      WHEN C_CLOB     THEN RETURN L_VALUE.CLOB_VALUE;
      ELSE                 RAISE VALUE_ERROR;
    END CASE;
EXCEPTION WHEN NO_DATA_FOUND THEN RETURN P_DEFAULT;
END GET_CLOB;


FUNCTION GET_DATE (
    P_PATH             IN VARCHAR2,
    P0                 IN VARCHAR2 DEFAULT NULL,
    P1                 IN VARCHAR2 DEFAULT NULL,
    P2                 IN VARCHAR2 DEFAULT NULL,
    P3                 IN VARCHAR2 DEFAULT NULL,
    P4                 IN VARCHAR2 DEFAULT NULL,
    P_DEFAULT          IN DATE     DEFAULT NULL,
    P_FORMAT           IN VARCHAR2 DEFAULT NULL,
    P_VALUES           IN T_VALUES DEFAULT G_VALUES,
    P_AT_TIME_ZONE     IN VARCHAR2 DEFAULT NULL )
    RETURN DATE
IS
    L_VALUE  T_VALUE;
    L_FORMAT VARCHAR2(255) := P_FORMAT;
BEGIN
    IF P0 IS NULL THEN
        L_VALUE := P_VALUES(P_PATH);
    ELSE
        L_VALUE := P_VALUES(FORMAT(P_PATH, P0, P1, P2, P3, P4));
    END IF;

    IF L_FORMAT IS NULL THEN
        L_FORMAT := CASE WHEN P_AT_TIME_ZONE IS NULL THEN C_DATE_ISO8601 ELSE C_TIMESTAMP_ISO8601_TZR END;
    END IF;

    CASE L_VALUE.KIND
      WHEN C_VARCHAR2 THEN
          CASE WHEN P_AT_TIME_ZONE IS NULL THEN
              RETURN TO_DATE( L_VALUE.VARCHAR2_VALUE, L_FORMAT );
          ELSE
              RETURN CAST( TO_TIMESTAMP_TZ(L_VALUE.VARCHAR2_VALUE, L_FORMAT) AT TIME ZONE P_AT_TIME_ZONE AS DATE );
          END CASE;
      ELSE                 RAISE VALUE_ERROR;
    END CASE;
EXCEPTION WHEN NO_DATA_FOUND THEN RETURN P_DEFAULT;
END GET_DATE;


FUNCTION GET_TIMESTAMP (
    P_PATH             IN VARCHAR2,
    P0                 IN VARCHAR2  DEFAULT NULL,
    P1                 IN VARCHAR2  DEFAULT NULL,
    P2                 IN VARCHAR2  DEFAULT NULL,
    P3                 IN VARCHAR2  DEFAULT NULL,
    P4                 IN VARCHAR2  DEFAULT NULL,
    P_DEFAULT          IN TIMESTAMP DEFAULT NULL,
    P_FORMAT           IN VARCHAR2  DEFAULT NULL,
    P_VALUES           IN T_VALUES  DEFAULT G_VALUES,
    P_AT_TIME_ZONE     IN VARCHAR2  DEFAULT NULL )
    RETURN TIMESTAMP
IS
    L_VALUE  T_VALUE;
    L_FORMAT VARCHAR2(255) := P_FORMAT;
BEGIN
    IF P0 IS NULL THEN
        L_VALUE := P_VALUES(P_PATH);
    ELSE
        L_VALUE := P_VALUES(FORMAT(P_PATH, P0, P1, P2, P3, P4));
    END IF;

    IF L_FORMAT IS NULL THEN
        L_FORMAT := CASE WHEN P_AT_TIME_ZONE IS NULL THEN C_TIMESTAMP_ISO8601_FF ELSE C_TIMESTAMP_ISO8601_TZR END;
    END IF;

    CASE L_VALUE.KIND
      WHEN C_VARCHAR2 THEN 
          CASE WHEN P_AT_TIME_ZONE IS NULL THEN
              RETURN TO_TIMESTAMP( L_VALUE.VARCHAR2_VALUE, L_FORMAT );
          ELSE
              RETURN CAST( TO_TIMESTAMP_TZ(L_VALUE.VARCHAR2_VALUE, L_FORMAT) AT TIME ZONE P_AT_TIME_ZONE AS TIMESTAMP );
          END CASE;
      ELSE                 RAISE VALUE_ERROR;
    END CASE;
EXCEPTION WHEN NO_DATA_FOUND THEN RETURN P_DEFAULT;
END GET_TIMESTAMP;


FUNCTION GET_TIMESTAMP_LTZ (
    P_PATH             IN VARCHAR2,
    P0                 IN VARCHAR2  DEFAULT NULL,
    P1                 IN VARCHAR2  DEFAULT NULL,
    P2                 IN VARCHAR2  DEFAULT NULL,
    P3                 IN VARCHAR2  DEFAULT NULL,
    P4                 IN VARCHAR2  DEFAULT NULL,
    P_DEFAULT          IN TIMESTAMP WITH LOCAL TIME ZONE DEFAULT NULL,
    P_FORMAT           IN VARCHAR2  DEFAULT C_TIMESTAMP_ISO8601_FF_TZR,
    P_VALUES           IN T_VALUES  DEFAULT G_VALUES )
    RETURN TIMESTAMP WITH LOCAL TIME ZONE
IS
    L_VALUE T_VALUE;
BEGIN
    IF P0 IS NULL THEN
        L_VALUE := P_VALUES(P_PATH);
    ELSE
        L_VALUE := P_VALUES(FORMAT(P_PATH, P0, P1, P2, P3, P4));
    END IF;

    CASE L_VALUE.KIND
      WHEN C_VARCHAR2 THEN RETURN CAST(TO_TIMESTAMP_TZ(L_VALUE.VARCHAR2_VALUE, P_FORMAT) AS TIMESTAMP WITH LOCAL TIME ZONE);
      ELSE                 RAISE VALUE_ERROR;
    END CASE;
EXCEPTION WHEN NO_DATA_FOUND THEN RETURN P_DEFAULT;
END GET_TIMESTAMP_LTZ;


FUNCTION GET_TIMESTAMP_TZ (
    P_PATH             IN VARCHAR2,
    P0                 IN VARCHAR2  DEFAULT NULL,
    P1                 IN VARCHAR2  DEFAULT NULL,
    P2                 IN VARCHAR2  DEFAULT NULL,
    P3                 IN VARCHAR2  DEFAULT NULL,
    P4                 IN VARCHAR2  DEFAULT NULL,
    P_DEFAULT          IN TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    P_FORMAT           IN VARCHAR2  DEFAULT C_TIMESTAMP_ISO8601_FF_TZR,
    P_VALUES           IN T_VALUES  DEFAULT G_VALUES )
    RETURN TIMESTAMP WITH TIME ZONE
IS
    L_VALUE T_VALUE;
BEGIN
    IF P0 IS NULL THEN
        L_VALUE := P_VALUES(P_PATH);
    ELSE
        L_VALUE := P_VALUES(FORMAT(P_PATH, P0, P1, P2, P3, P4));
    END IF;

    CASE L_VALUE.KIND
      WHEN C_VARCHAR2 THEN RETURN TO_TIMESTAMP_TZ(L_VALUE.VARCHAR2_VALUE, P_FORMAT);
      ELSE                 RAISE VALUE_ERROR;
    END CASE;
EXCEPTION WHEN NO_DATA_FOUND THEN RETURN P_DEFAULT;
END GET_TIMESTAMP_TZ;


FUNCTION GET_COUNT (
    P_PATH             IN VARCHAR2,
    P0                 IN VARCHAR2 DEFAULT NULL,
    P1                 IN VARCHAR2 DEFAULT NULL,
    P2                 IN VARCHAR2 DEFAULT NULL,
    P3                 IN VARCHAR2 DEFAULT NULL,
    P4                 IN VARCHAR2 DEFAULT NULL,
    P_VALUES           IN T_VALUES DEFAULT G_VALUES )
    RETURN NUMBER
IS
    L_VALUE T_VALUE;
BEGIN
    IF P0 IS NULL THEN
        L_VALUE := P_VALUES(P_PATH);
    ELSE
        L_VALUE := P_VALUES(FORMAT(P_PATH, P0, P1, P2, P3, P4));
    END IF;

    CASE L_VALUE.KIND
      WHEN C_OBJECT  THEN RETURN L_VALUE.OBJECT_MEMBERS.COUNT;
      WHEN C_ARRAY   THEN RETURN L_VALUE.NUMBER_VALUE;
      ELSE                RAISE VALUE_ERROR;
    END CASE;
EXCEPTION WHEN NO_DATA_FOUND THEN RETURN NULL;
END GET_COUNT;


FUNCTION GET_MEMBERS (
    P_PATH             IN VARCHAR2,
    P0                 IN VARCHAR2 DEFAULT NULL,
    P1                 IN VARCHAR2 DEFAULT NULL,
    P2                 IN VARCHAR2 DEFAULT NULL,
    P3                 IN VARCHAR2 DEFAULT NULL,
    P4                 IN VARCHAR2 DEFAULT NULL,
    P_VALUES           IN T_VALUES DEFAULT G_VALUES )
    RETURN apx_T_VARCHAR2
IS
    L_VALUE T_VALUE;
BEGIN
    IF P0 IS NULL THEN
        L_VALUE := P_VALUES(P_PATH);
    ELSE
        L_VALUE := P_VALUES(FORMAT(P_PATH, P0, P1, P2, P3, P4));
    END IF;

    CASE L_VALUE.KIND
      WHEN C_OBJECT  THEN RETURN L_VALUE.OBJECT_MEMBERS;
      ELSE                RAISE VALUE_ERROR;
    END CASE;
EXCEPTION WHEN NO_DATA_FOUND THEN RETURN NULL;
END GET_MEMBERS;


FUNCTION GET_T_VARCHAR2 (
    P_PATH             IN VARCHAR2,
    P0                 IN VARCHAR2 DEFAULT NULL,
    P1                 IN VARCHAR2 DEFAULT NULL,
    P2                 IN VARCHAR2 DEFAULT NULL,
    P3                 IN VARCHAR2 DEFAULT NULL,
    P4                 IN VARCHAR2 DEFAULT NULL,
    P_VALUES           IN T_VALUES DEFAULT G_VALUES )
    RETURN apx_T_VARCHAR2
IS
    L_ELEMENTS    apx_T_VARCHAR2 := apx_T_VARCHAR2();
    L_ARRAY_PATH  VARCHAR2(32767);
    L_ARRAY_VALUE T_VALUE;
BEGIN
    IF P0 IS NULL THEN
        L_ARRAY_PATH  := P_PATH;
    ELSE
        L_ARRAY_PATH  := FORMAT(P_PATH, P0, P1, P2, P3, P4);
    END IF;

    L_ARRAY_VALUE := P_VALUES(L_ARRAY_PATH);

    IF L_ARRAY_VALUE.KIND = C_ARRAY THEN
        FOR I IN 1 .. L_ARRAY_VALUE.NUMBER_VALUE LOOP
            L_ELEMENTS.EXTEND;
            PRAGMA INLINE(T_VALUE_TO_CHAR,'YES');
            L_ELEMENTS(L_ELEMENTS.COUNT) := T_VALUE_TO_CHAR(P_VALUES(L_ARRAY_PATH||'['||I||']'));
        END LOOP;
    ELSE
        L_ELEMENTS.EXTEND;
        PRAGMA INLINE(T_VALUE_TO_CHAR,'YES');
        L_ELEMENTS(1) := T_VALUE_TO_CHAR(L_ARRAY_VALUE);
    END IF;

    RETURN L_ELEMENTS;
EXCEPTION WHEN NO_DATA_FOUND THEN RETURN NULL;
END GET_T_VARCHAR2;


FUNCTION GET_T_NUMBER (
    P_PATH             IN VARCHAR2,
    P0                 IN VARCHAR2 DEFAULT NULL,
    P1                 IN VARCHAR2 DEFAULT NULL,
    P2                 IN VARCHAR2 DEFAULT NULL,
    P3                 IN VARCHAR2 DEFAULT NULL,
    P4                 IN VARCHAR2 DEFAULT NULL,
    P_VALUES           IN T_VALUES DEFAULT G_VALUES )
    RETURN apx_T_NUMBER
IS
    L_ELEMENTS    apx_T_NUMBER := apx_T_NUMBER();
    L_ARRAY_PATH  VARCHAR2(32767);
    L_ARRAY_VALUE T_VALUE;
BEGIN
    IF P0 IS NULL THEN
        L_ARRAY_PATH  := P_PATH;
    ELSE
        L_ARRAY_PATH  := FORMAT(P_PATH, P0, P1, P2, P3, P4);
    END IF;

    L_ARRAY_VALUE := P_VALUES(L_ARRAY_PATH);

    IF L_ARRAY_VALUE.KIND = C_ARRAY THEN
        FOR I IN 1 .. L_ARRAY_VALUE.NUMBER_VALUE LOOP
            L_ELEMENTS.EXTEND;
            PRAGMA INLINE(T_VALUE_TO_NUMBER,'YES');
            L_ELEMENTS(L_ELEMENTS.COUNT) := T_VALUE_TO_NUMBER(P_VALUES(L_ARRAY_PATH||'['||I||']'));
        END LOOP;
    ELSE
        L_ELEMENTS.EXTEND;
        PRAGMA INLINE(T_VALUE_TO_NUMBER,'YES');
        L_ELEMENTS(1) := T_VALUE_TO_NUMBER(L_ARRAY_VALUE);
    END IF;

    RETURN L_ELEMENTS;
EXCEPTION WHEN NO_DATA_FOUND THEN RETURN NULL;
END GET_T_NUMBER;


FUNCTION GET_VALUE (
    P_PATH             IN VARCHAR2,
    P0                 IN VARCHAR2 DEFAULT NULL,
    P1                 IN VARCHAR2 DEFAULT NULL,
    P2                 IN VARCHAR2 DEFAULT NULL,
    P3                 IN VARCHAR2 DEFAULT NULL,
    P4                 IN VARCHAR2 DEFAULT NULL,
    P_VALUES           IN T_VALUES DEFAULT G_VALUES )
    RETURN T_VALUE
IS
    L_VALUE T_VALUE;
BEGIN
    IF P0 IS NULL THEN
        L_VALUE := P_VALUES(P_PATH);
    ELSE
        L_VALUE := P_VALUES(FORMAT(P_PATH, P0, P1, P2, P3, P4));
    END IF;

    RETURN L_VALUE;
EXCEPTION WHEN NO_DATA_FOUND THEN
    RETURN L_VALUE;
END GET_VALUE;


FUNCTION FIND_PATHS_LIKE (
    P_RETURN_PATH      IN VARCHAR2,
    P_SUBPATH          IN VARCHAR2 DEFAULT NULL,
    P_VALUE            IN VARCHAR2 DEFAULT NULL,
    P_VALUES           IN T_VALUES DEFAULT G_VALUES )
    RETURN apx_T_VARCHAR2
IS
    L_FOUND_PATHS           apx_T_VARCHAR2          := apx_T_VARCHAR2();
    L_RETURN_PATH           VARCHAR2(32767);
    L_QUERY_PARTS           apx_T_VARCHAR2;
    L_QUERY_PARTS_COUNT     PLS_INTEGER;
    L_RETURN_PATH_MATCH_IDX PLS_INTEGER;



    PROCEDURE DO_APPEND (
        P_PATH IN VARCHAR2 )
    IS
    BEGIN
        IF NOT P_PATH MEMBER OF L_FOUND_PATHS THEN
            L_FOUND_PATHS.EXTEND;
            L_FOUND_PATHS(L_FOUND_PATHS.COUNT) := P_PATH;

        END IF;
    END DO_APPEND;



    FUNCTION VALUE_MATCHES (
        P_CURRENT     IN T_VALUE )
        RETURN BOOLEAN
    IS
    BEGIN
        RETURN CASE P_CURRENT.KIND
                 WHEN C_TRUE     THEN 'true' LIKE P_VALUE
                 WHEN C_FALSE    THEN 'false' LIKE P_VALUE
                 WHEN C_NUMBER   THEN STRINGIFY(P_CURRENT.NUMBER_VALUE) LIKE P_VALUE
                 WHEN C_VARCHAR2 THEN P_CURRENT.VARCHAR2_VALUE LIKE P_VALUE
                 ELSE                 FALSE
               END;
    END VALUE_MATCHES;




    FUNCTION COMPUTE_MATCH_IDX (
        P_PATH             IN VARCHAR2,
        P_PARENT_MATCH_IDX IN PLS_INTEGER )
        RETURN PLS_INTEGER
    IS
        L_NEW_IDX PLS_INTEGER := P_PARENT_MATCH_IDX+1;
    BEGIN
        IF     L_NEW_IDX < L_QUERY_PARTS_COUNT
           AND P_PATH LIKE L_QUERY_PARTS(L_NEW_IDX)
        THEN
            IF P_PATH LIKE L_QUERY_PARTS(L_QUERY_PARTS_COUNT) THEN
                L_NEW_IDX := L_QUERY_PARTS_COUNT;
            END IF;
        ELSIF  L_NEW_IDX = L_QUERY_PARTS_COUNT
           AND P_PATH LIKE L_QUERY_PARTS(L_QUERY_PARTS_COUNT)
        THEN
            L_NEW_IDX := L_QUERY_PARTS_COUNT;
        ELSE
            L_NEW_IDX := P_PARENT_MATCH_IDX;
        END IF;



        RETURN L_NEW_IDX;
    END COMPUTE_MATCH_IDX;







    PROCEDURE APPEND_PATHS_UNDER (
        P_PATH      IN VARCHAR2,
        P_MATCH_IDX IN PLS_INTEGER )
    IS
        L_CURRENT             T_VALUE;
        L_RETURN_PATH_MATCHED BOOLEAN;
        L_BASE_PATH           VARCHAR2(32767);
        L_CANDIDATE_PATHS     apx_T_VARCHAR2;
        L_CANDIDATE_MATCHES   apx_T_NUMBER;
        L_CANDIDATE_MAX_MATCH PLS_INTEGER := 0;
        PROCEDURE APPEND_CANDIDATE (
            P_PATH      IN VARCHAR2,
            P_PARENT_MATCH_IDX IN PLS_INTEGER )
        IS
        BEGIN




            IF L_CANDIDATE_PATHS IS NULL THEN
                L_CANDIDATE_PATHS   := apx_T_VARCHAR2();
                L_CANDIDATE_MATCHES := apx_T_NUMBER();
            END IF;
            L_CANDIDATE_PATHS.EXTEND;
            L_CANDIDATE_MATCHES.EXTEND;
            L_CANDIDATE_PATHS(L_CANDIDATE_PATHS.COUNT)   := P_PATH;
            L_CANDIDATE_MATCHES(L_CANDIDATE_PATHS.COUNT) := COMPUTE_MATCH_IDX (
                                                                P_PATH             => P_PATH,
                                                                P_PARENT_MATCH_IDX => P_PARENT_MATCH_IDX );
            L_CANDIDATE_MAX_MATCH := GREATEST (
                                         L_CANDIDATE_MAX_MATCH,
                                         L_CANDIDATE_MATCHES(L_CANDIDATE_PATHS.COUNT) );
        END APPEND_CANDIDATE;
    BEGIN







        IF L_RETURN_PATH IS NULL AND P_MATCH_IDX >= L_RETURN_PATH_MATCH_IDX THEN
            L_RETURN_PATH_MATCHED := TRUE;
            L_RETURN_PATH         := P_PATH;
        END IF;





        L_CURRENT := P_VALUES(P_PATH);
        IF P_MATCH_IDX = L_QUERY_PARTS_COUNT
            AND (    P_VALUE IS NULL
                  OR VALUE_MATCHES(L_CURRENT) )
        THEN
            DO_APPEND(P_PATH => L_RETURN_PATH);
            L_RETURN_PATH := NULL;
            RETURN;
        END IF;

        IF L_CURRENT.KIND = C_ARRAY THEN



            L_BASE_PATH := NULLIF(P_PATH, '.');

            FOR I IN 1 .. L_CURRENT.NUMBER_VALUE LOOP
                APPEND_CANDIDATE (
                    P_PATH             => L_BASE_PATH||'['||I||']',
                    P_PARENT_MATCH_IDX => P_MATCH_IDX );
            END LOOP;
        ELSIF L_CURRENT.KIND = C_OBJECT THEN



            L_BASE_PATH := CASE
                             WHEN P_PATH = '.' THEN NULL
                             ELSE P_PATH||'.'
                           END;
            FOR I IN 1 .. L_CURRENT.OBJECT_MEMBERS.COUNT LOOP
                APPEND_CANDIDATE (
                    P_PATH             => L_BASE_PATH||L_CURRENT.OBJECT_MEMBERS(I),
                    P_PARENT_MATCH_IDX => P_MATCH_IDX );
            END LOOP;
        END IF;




        IF L_CANDIDATE_PATHS IS NOT NULL THEN
            FOR I IN 1 .. L_CANDIDATE_PATHS.COUNT LOOP
                IF L_CANDIDATE_MATCHES(I) = L_CANDIDATE_MAX_MATCH THEN
                    APPEND_PATHS_UNDER (
                        P_PATH      => L_CANDIDATE_PATHS(I),
                        P_MATCH_IDX => L_CANDIDATE_MATCHES(I) );
                END IF;
            END LOOP;
        END IF;



        IF L_RETURN_PATH_MATCHED THEN
            L_RETURN_PATH := NULL;
        END IF;
    END APPEND_PATHS_UNDER;

    FUNCTION SPLIT_QUERY (
        P_QUERY IN VARCHAR2 )
        RETURN apx_T_VARCHAR2
    IS
    BEGIN
        RETURN SPLIT (
                   TRIM (
                       BOTH '|' FROM
                       REPLACE (
                           REGEXP_REPLACE (
                               P_QUERY,
                               '(\[[^\]]*|%|\.)',
                               '|\1' ),
                           '||', '|' )),
                   '|' );
    END SPLIT_QUERY;

BEGIN
    L_QUERY_PARTS           := SPLIT_QUERY(P_QUERY => P_RETURN_PATH);
    L_RETURN_PATH_MATCH_IDX := L_QUERY_PARTS.COUNT;
    IF P_SUBPATH IS NOT NULL THEN
        PUSH (
            L_QUERY_PARTS,
            SPLIT_QUERY (
                P_QUERY => P_SUBPATH ));
    END IF;
    L_QUERY_PARTS_COUNT    := L_QUERY_PARTS.COUNT;
    FOR I IN 2 .. L_QUERY_PARTS_COUNT LOOP
        L_QUERY_PARTS(I) := L_QUERY_PARTS(I-1)||L_QUERY_PARTS(I);
    END LOOP;



    APPEND_PATHS_UNDER (
        P_PATH      => '.',
        P_MATCH_IDX => 0 );

    RETURN L_FOUND_PATHS;
END FIND_PATHS_LIKE;

PROCEDURE DATA_WRITTEN_AT_CURRENT_LEVEL
IS
BEGIN
    IF G_OUTPUT.NESTING_AT_CURRENT_LEVEL < 0 THEN
        G_OUTPUT.NESTING_AT_CURRENT_LEVEL        := ABS(G_OUTPUT.NESTING_AT_CURRENT_LEVEL);
        G_OUTPUT.NESTING(G_OUTPUT.NESTING_LEVEL) := G_OUTPUT.NESTING_AT_CURRENT_LEVEL;
    END IF;
END DATA_WRITTEN_AT_CURRENT_LEVEL;


PROCEDURE INCREASE_NESTING (
    P_NESTING_VALUE IN T_NESTING_VALUE )
IS
BEGIN
    IF G_OUTPUT.NESTING_LEVEL > 0 THEN
        PRAGMA INLINE(DATA_WRITTEN_AT_CURRENT_LEVEL, 'YES');
        DATA_WRITTEN_AT_CURRENT_LEVEL;
        G_OUTPUT.NESTING_LEVEL := G_OUTPUT.NESTING_LEVEL + 1;
    ELSE
        G_OUTPUT.NESTING_LEVEL := 1;
        IF G_OUTPUT.HTTP_HEADER THEN
            G_OUTPUT.HTTP_HEADER := FALSE;
        END IF;
    END IF;
    G_OUTPUT.NESTING_AT_CURRENT_LEVEL        := P_NESTING_VALUE;
    G_OUTPUT.NESTING(G_OUTPUT.NESTING_LEVEL) := P_NESTING_VALUE;
END INCREASE_NESTING;


FUNCTION DECREASE_NESTING (
    P_NESTING_VALUE IN T_NESTING_VALUE )
    RETURN BOOLEAN
IS
BEGIN
    IF     G_OUTPUT.NESTING_LEVEL > 0
       AND G_OUTPUT.NESTING_AT_CURRENT_LEVEL IN (P_NESTING_VALUE, -P_NESTING_VALUE)
    THEN
        G_OUTPUT.NESTING_LEVEL            := G_OUTPUT.NESTING_LEVEL - 1;
        IF G_OUTPUT.NESTING_LEVEL > 0 THEN
            G_OUTPUT.NESTING_AT_CURRENT_LEVEL := G_OUTPUT.NESTING(G_OUTPUT.NESTING_LEVEL);
        ELSE
            G_OUTPUT.NESTING_AT_CURRENT_LEVEL := 0;
        END IF;
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END DECREASE_NESTING;


FUNCTION GET_INDENT (
    P_COMMA  IN BOOLEAN DEFAULT TRUE )
    RETURN VARCHAR2
IS
    L_INDENT_CHARS PLS_INTEGER;
    L_INDENT       VARCHAR2(4000);
BEGIN
    IF G_OUTPUT.NESTING_LEVEL > 0 THEN
        IF G_OUTPUT.INDENT > 0 THEN
            L_INDENT_CHARS := G_OUTPUT.NESTING_LEVEL*G_OUTPUT.INDENT;
            IF P_COMMA AND G_OUTPUT.NESTING_AT_CURRENT_LEVEL > 0 THEN
                L_INDENT := LPAD(',', L_INDENT_CHARS);
            ELSE
                L_INDENT := LPAD(' ', L_INDENT_CHARS);
            END IF;
        ELSIF P_COMMA AND G_OUTPUT.NESTING_AT_CURRENT_LEVEL > 0 THEN
            L_INDENT := ',';
        END IF;
    END IF;
    RETURN L_INDENT;
END GET_INDENT;


PROCEDURE WRITE_RAW (
    P_VALUE  IN VARCHAR2,
    P_DONE   IN BOOLEAN )
IS
    L_INDENT VARCHAR2(4000);
BEGIN
    IF G_OUTPUT.NESTING_LEVEL = 0 THEN
        raise_application_error( -20001, 'JSON.WRITER.NOT_OPEN' );
    END IF;

    PRAGMA INLINE(GET_INDENT, 'YES');
    L_INDENT := GET_INDENT;

    IF P_DONE THEN
        IF L_INDENT IS NULL THEN
            G_WRITER.P(P_VALUE);
        ELSIF LENGTH(P_VALUE) < 30000 THEN
            G_WRITER.P(L_INDENT||P_VALUE);
        ELSE
            G_WRITER.PRN(L_INDENT);
            G_WRITER.P(P_VALUE);
        END IF;

        PRAGMA INLINE(DATA_WRITTEN_AT_CURRENT_LEVEL, 'YES');
        DATA_WRITTEN_AT_CURRENT_LEVEL;
    ELSE
        IF L_INDENT IS NULL THEN
            G_WRITER.PRN(P_VALUE);
        ELSE

            G_WRITER.PRN(L_INDENT||P_VALUE);
        END IF;
    END IF;
END WRITE_RAW;


PROCEDURE WRITE_RAW (
    P_VALUE IN VARCHAR2 )
IS
BEGIN
    PRAGMA INLINE(WRITE_RAW, 'YES');
    WRITE_RAW (
        P_VALUE => P_VALUE,
        P_DONE  => TRUE );
END WRITE_RAW;


PROCEDURE WRITE_RAW (
    P_VALUE IN VC_ARR2 )
IS
    C_COUNT  CONSTANT BINARY_INTEGER := P_VALUE.COUNT;
    L_INDENT VARCHAR2(4000);
BEGIN
    PRAGMA INLINE(GET_INDENT, 'YES');
    L_INDENT := GET_INDENT;

    IF L_INDENT IS NOT NULL THEN
        G_WRITER.PRN(L_INDENT);
    END IF;

    FOR I IN 1 .. C_COUNT-1 LOOP
        G_WRITER.PRN(P_VALUE(I));
    END LOOP;
    IF C_COUNT > 0 THEN
        G_WRITER.P(P_VALUE(C_COUNT));
    ELSE
        G_WRITER.P(TO_CHAR(NULL));
    END IF;
    PRAGMA INLINE(DATA_WRITTEN_AT_CURRENT_LEVEL, 'YES');
    DATA_WRITTEN_AT_CURRENT_LEVEL;
END WRITE_RAW;


PROCEDURE WRITE_RAW_NAME (
    P_NAME   IN VARCHAR2 )
IS
    L_NAME VARCHAR2(32767);
BEGIN
    IF NVL(LENGTH(LTRIM(P_NAME,
                        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890_')),
            0) = 0
    THEN



        L_NAME := '"'||P_NAME||'":';
    ELSIF ASCII(P_NAME) = C_DOUBLEQUOTE# THEN



        L_NAME := P_NAME||':';
    ELSE
        L_NAME := '"'||JSON(P_NAME)||'":';
    END IF;
    PRAGMA INLINE(WRITE_RAW, 'YES');
    WRITE_RAW (
        P_VALUE => L_NAME,
        P_DONE  => FALSE );
END WRITE_RAW_NAME;


PROCEDURE WRITE_RAW (
    P_NAME   IN VARCHAR2,
    P_VALUE  IN VARCHAR2 )
IS
BEGIN
    PRAGMA INLINE(WRITE_RAW_NAME, 'YES');
    WRITE_RAW_NAME(P_NAME);
    G_WRITER.P(P_VALUE);

    PRAGMA INLINE(DATA_WRITTEN_AT_CURRENT_LEVEL, 'YES');
    DATA_WRITTEN_AT_CURRENT_LEVEL;
END WRITE_RAW;





PROCEDURE FINISH_WRITE_LONG_VARCHAR2 (
    P_VALUE  IN VARCHAR2,
    P_LENGTH IN PLS_INTEGER )
IS
    L_OFFSET PLS_INTEGER;
BEGIN
    L_OFFSET := 1;
    WHILE L_OFFSET <= P_LENGTH LOOP
        G_WRITER.PRN(JSON(
                SUBSTR (
                    P_VALUE,
                    L_OFFSET,
                    C_STRINGIFY_LENGTH )));
        L_OFFSET := L_OFFSET + C_STRINGIFY_LENGTH;
    END LOOP;

    G_WRITER.P('"');

    PRAGMA INLINE(DATA_WRITTEN_AT_CURRENT_LEVEL, 'YES');
    DATA_WRITTEN_AT_CURRENT_LEVEL;
END FINISH_WRITE_LONG_VARCHAR2;





PROCEDURE FINISH_WRITE_CLOB (
    P_VALUE IN CLOB )
IS
    L_LENGTH PLS_INTEGER;
    L_OFFSET PLS_INTEGER;
    L_AMOUNT PLS_INTEGER;
    L_BUFFER VARCHAR2(32767);
BEGIN
    WHILE NEXT_CHUNK (
              P_STR    => P_VALUE,
              P_CHUNK  => L_BUFFER,
              P_OFFSET => L_OFFSET,
              P_AMOUNT => C_STRINGIFY_LENGTH )
    LOOP
        G_WRITER.PRN(JSON(L_BUFFER));
    END LOOP;
    G_WRITER.P('"');

    PRAGMA INLINE(DATA_WRITTEN_AT_CURRENT_LEVEL, 'YES');
    DATA_WRITTEN_AT_CURRENT_LEVEL;
END FINISH_WRITE_CLOB;








FUNCTION GET_XML_TO_JSON
    RETURN SYS.XMLTYPE
IS
BEGIN
    IF G_XML_TO_JSON IS NULL THEN
        G_XML_TO_JSON := SYS.XMLTYPE.CREATEXML(q'#<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output indent="no" omit-xml-declaration="yes" encoding="utf-8" method="xml"/>
<xsl:strip-space elements="*"/>
<!-- -->
<xsl:template name="enquote-string">
    <xsl:param name="str"/>
    <xsl:text>"</xsl:text>
    <xsl:value-of select="translate($str,'&quot;','&#x7F;')"/>
    <xsl:text>"</xsl:text>
</xsl:template>
<!--
    Print value which can be null, true, false, numeric or enquoted string. The
    numeric check in XPath has flaws. We need to prevent
      - " 123"
      - "-0123"
      - "0123"
      - ".123."
      - "123."
    from being emitted as numbers.
-->
<xsl:template name="value">
    <xsl:param name="str"/>
    <xsl:variable name="str_len" select="string-length($str)"/>
    <xsl:choose>
        <xsl:when test="$str_len=0">null</xsl:when>
        <xsl:when test="string(number($str))!='NaN'">
            <xsl:choose>
                <xsl:when test="contains('1234567890',$str)"><xsl:value-of select="$str"/></xsl:when>
                <xsl:when test="not(contains('1234567890.-',substring($str,1,1)))
                                or (starts-with($str,'-0') and not(starts-with($str,'-0.')))
                                or (starts-with($str,'0') and not(starts-with($str,'0.')))
                                or (contains($str,'.') and contains(substring-after($str,'.'),'.'))
                                or substring($str,$str_len)='.'">
                    <xsl:call-template name="enquote-string">
                        <xsl:with-param name="str" select="$str"/>
                    </xsl:call-template>
                </xsl:when>
                <xsl:when test="starts-with($str,'.')">
                    <xsl:value-of select="concat('0',$str)"/>
                </xsl:when>
                <xsl:when test="starts-with($str,'-.')">
                    <xsl:value-of select="concat('-0.',substring($str,3))"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="$str"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:when>
        <xsl:when test="$str_len=4 and translate($str,'TRUE','true')='true'">true</xsl:when>
        <xsl:when test="$str_len=5 and translate($str,'FALSE','false')='false'">false</xsl:when>
        <xsl:otherwise>
            <xsl:call-template name="enquote-string">
                <xsl:with-param name="str" select="$str"/>
            </xsl:call-template>
        </xsl:otherwise>
    </xsl:choose>
</xsl:template>
<!-- -->
<xsl:template match="*">
    <xsl:variable name="cnt" select="count(*)"/>
    <xsl:variable name="cnt_attrs" select="count(@*)"/>
    <xsl:choose>
    <!-- array if no attributes, more than 1 node, first child's name=last child's name and ( >1 child or node is rowset or node is object table (x0028__x0027) or child ends in "_row" -->
        <xsl:when test="$cnt&gt;0 and name(*[1])=name(*[last()]) and ($cnt&gt;1 or translate(name(),'ROWSET','rowset')='rowset' or contains(name(*[1]), 'x0028__x0027') or substring(translate(name(*[1]),'ROW','row'),string-length(name(*[1]))-3)='_row')">
            <xsl:text>[</xsl:text>
            <!-- object attributes -->
            <xsl:for-each select="@*">
                <xsl:if test="position() &gt; 1"><xsl:text>,</xsl:text></xsl:if>
                <xsl:text>{</xsl:text>
                <xsl:call-template name="enquote-string"><xsl:with-param name="str" select="concat('@',name())"/></xsl:call-template>
                <xsl:text>:</xsl:text>
                <xsl:call-template name="value"><xsl:with-param name="str" select="."/></xsl:call-template>
                <xsl:text>}</xsl:text>
            </xsl:for-each>
            <!-- object children -->
            <xsl:for-each select="*">
                <xsl:if test="$cnt_attrs &gt; 0 or position() &gt; 1"><xsl:text>,</xsl:text></xsl:if>
                <xsl:apply-templates select="."/>
            </xsl:for-each>
            <xsl:text>]</xsl:text>
        </xsl:when>
        <!-- object if node has attributes or first child's name <> last child's name -->
        <xsl:when test="$cnt_attrs&gt;0 or $cnt&gt;0">
            <xsl:text>{</xsl:text>
            <!-- object attributes -->
            <xsl:for-each select="@*">
                <xsl:if test="position() &gt; 1"><xsl:text>,</xsl:text></xsl:if>
                <xsl:call-template name="enquote-string"><xsl:with-param name="str" select="concat('@',name())"/></xsl:call-template>
                <xsl:text>:</xsl:text>
                <xsl:call-template name="value"><xsl:with-param name="str" select="."/></xsl:call-template>
            </xsl:for-each>
            <!-- object children -->
            <xsl:for-each select="*">
                <xsl:if test="$cnt_attrs &gt; 0 or position() &gt; 1"><xsl:text>,</xsl:text></xsl:if>
                <xsl:call-template name="enquote-string"><xsl:with-param name="str" select="name(.)"/></xsl:call-template>
                <xsl:text>:</xsl:text>
                <xsl:apply-templates select="."/>
            </xsl:for-each>
            <!-- object text -->
            <xsl:if test="text()">
                <xsl:text>,"@text":</xsl:text>
                <xsl:call-template name="value"><xsl:with-param name="str" select="text()"/></xsl:call-template>
            </xsl:if>
            <xsl:text>}</xsl:text>
        </xsl:when>
        <!-- text if non-empty -->
        <xsl:when test="normalize-space(text())">
            <xsl:call-template name="value"><xsl:with-param name="str" select="text()"/></xsl:call-template>
        </xsl:when>
        <!-- null otherwise -->
        <xsl:otherwise>
            <xsl:text>null</xsl:text>
        </xsl:otherwise>
    </xsl:choose>
</xsl:template>
</xsl:stylesheet>#');
    END IF;

    RETURN G_XML_TO_JSON;
END GET_XML_TO_JSON;








PROCEDURE INITIALIZE_OUTPUT (
    P_HTTP_HEADER     IN BOOLEAN     DEFAULT TRUE,
    P_HTTP_CACHE      IN BOOLEAN     DEFAULT FALSE,
    P_HTTP_CACHE_ETAG IN VARCHAR2    DEFAULT NULL,
    P_INDENT          IN PLS_INTEGER DEFAULT NULL )
IS
BEGIN
    FREE_OUTPUT;
    IF P_INDENT >= 0 THEN
        G_OUTPUT.INDENT := P_INDENT;
    END IF;
    G_OUTPUT.HTTP_HEADER     := P_HTTP_HEADER;
    G_OUTPUT.HTTP_CACHE      := P_HTTP_CACHE;
    G_OUTPUT.HTTP_CACHE_ETAG := P_HTTP_CACHE_ETAG;
    G_WRITER                 := apx_T_HTP_WRITER();
END INITIALIZE_OUTPUT;


PROCEDURE INITIALIZE_CLOB_OUTPUT (
    P_DUR         IN PLS_INTEGER DEFAULT SYS.DBMS_LOB.CALL,
    P_CACHE       IN BOOLEAN     DEFAULT TRUE,
    P_INDENT      IN PLS_INTEGER DEFAULT NULL )
IS
BEGIN
    FREE_OUTPUT;
    IF P_INDENT >= 0 THEN
        G_OUTPUT.INDENT := P_INDENT;
    END IF;
    G_WRITER := apx_T_CLOB_WRITER (
                           P_DUR   => P_DUR,
                           P_CACHE => P_CACHE );
END INITIALIZE_CLOB_OUTPUT;


PROCEDURE FREE_OUTPUT
IS
BEGIN
    G_OUTPUT.NESTING.DELETE;
    G_OUTPUT.NESTING_LEVEL            := 0;
    G_OUTPUT.NESTING_AT_CURRENT_LEVEL := 0;
    G_OUTPUT.HTTP_HEADER              := FALSE;
    G_OUTPUT.HTTP_CACHE               := FALSE;
    G_OUTPUT.INDENT                   := 0;
    G_WRITER.FREE;
END FREE_OUTPUT;


FUNCTION GET_CLOB_OUTPUT
    RETURN CLOB
IS
BEGIN
    FLUSH;
    RETURN TREAT(G_WRITER AS apx_T_CLOB_WRITER).L_CLOB;
END GET_CLOB_OUTPUT;


PROCEDURE FLUSH
IS
BEGIN
    G_WRITER.FLUSH();
END FLUSH;


PROCEDURE OPEN_OBJECT (
    P_NAME        IN VARCHAR2 DEFAULT NULL )
IS
    L_INDENT VARCHAR2(4000);
BEGIN
    PRAGMA INLINE(GET_INDENT, 'YES');
    L_INDENT := GET_INDENT;
    PRAGMA INLINE(INCREASE_NESTING, 'YES');
    INCREASE_NESTING (
        P_NESTING_VALUE => C_NESTING_OPENED_OBJECT );
    IF P_NAME IS NOT NULL THEN
        G_WRITER.P(L_INDENT||apx_JSON.STRINGIFY(P_NAME)||':{');
    ELSE
        G_WRITER.P (L_INDENT||'{');
    END IF;
END OPEN_OBJECT;


PROCEDURE CLOSE_OBJECT
IS
    L_INDENT VARCHAR2(4000);
BEGIN
    PRAGMA INLINE(DECREASE_NESTING, 'YES');
    IF DECREASE_NESTING (
           P_NESTING_VALUE => C_NESTING_OPENED_OBJECT )
    THEN
        PRAGMA INLINE(GET_INDENT, 'YES');
        L_INDENT := GET_INDENT (
                        P_COMMA => FALSE );
        G_WRITER.P (L_INDENT||'}');
        IF G_OUTPUT.NESTING_LEVEL = 0 THEN
            G_WRITER.FLUSH;
        END IF;
    ELSE
        raise_application_error( -20001, 'JSON.WRITER.CLOSE_OBJECT' );
    END IF;
END CLOSE_OBJECT;


PROCEDURE OPEN_ARRAY (
    P_NAME        IN VARCHAR2 DEFAULT NULL )
IS
    L_INDENT VARCHAR2(4000);
BEGIN
    PRAGMA INLINE(GET_INDENT, 'YES');
    L_INDENT := GET_INDENT;
    PRAGMA INLINE(INCREASE_NESTING, 'YES');
    INCREASE_NESTING (
        P_NESTING_VALUE => C_NESTING_OPENED_ARRAY );
    IF P_NAME IS NOT NULL THEN
        G_WRITER.P(L_INDENT||apx_JSON.STRINGIFY(P_NAME)||':[');
    ELSE
        G_WRITER.P(L_INDENT||'[');
    END IF;
END OPEN_ARRAY;


PROCEDURE CLOSE_ARRAY
IS
    L_INDENT VARCHAR2(4000);
BEGIN
    PRAGMA INLINE(DECREASE_NESTING, 'YES');
    IF DECREASE_NESTING (
           P_NESTING_VALUE => C_NESTING_OPENED_ARRAY )
    THEN
        PRAGMA INLINE(GET_INDENT, 'YES');
        L_INDENT := GET_INDENT (
                        P_COMMA => FALSE );
        G_WRITER.P(L_INDENT||']');
        IF G_OUTPUT.NESTING_LEVEL = 0 THEN
            G_WRITER.FLUSH;
        END IF;
    ELSE
        raise_application_error( -20001, 'JSON.WRITER.CLOSE_ARRAY' );
    END IF;
END CLOSE_ARRAY;


PROCEDURE CLOSE_ALL
IS
    L_COUNT BINARY_INTEGER := G_OUTPUT.NESTING_LEVEL;
    L_INDENT VARCHAR2(4000);
BEGIN
    FOR I IN REVERSE 1 .. L_COUNT LOOP
        G_OUTPUT.NESTING_LEVEL := G_OUTPUT.NESTING_LEVEL - 1;
        PRAGMA INLINE(GET_INDENT, 'YES');
        L_INDENT := GET_INDENT (
                        P_COMMA => FALSE );
        G_WRITER.P(L_INDENT||
                          CASE G_OUTPUT.NESTING(I)
                            WHEN C_NESTING_OPENED_OBJECT THEN '}'
                            WHEN C_NESTING_IN_OBJECT     THEN '}'
                            ELSE ']'
                          END);
    END LOOP;
    G_WRITER.FLUSH;
END CLOSE_ALL;








PROCEDURE WRITE (
    P_VALUE       IN VARCHAR2 )
IS
    L_LENGTH PLS_INTEGER := LENGTH(P_VALUE);
BEGIN
    IF L_LENGTH > C_STRINGIFY_LENGTH THEN
        PRAGMA INLINE(WRITE_RAW, 'YES');
        WRITE_RAW (
            P_VALUE => '"',
            P_DONE  => FALSE );

        PRAGMA INLINE(FINISH_WRITE_LONG_VARCHAR2, 'YES');
        FINISH_WRITE_LONG_VARCHAR2 (
            P_VALUE  => P_VALUE,
            P_LENGTH => L_LENGTH );
    ELSE
        PRAGMA INLINE(WRITE_RAW, 'YES');
        PRAGMA INLINE(STRINGIFY, 'YES');
        WRITE_RAW (
            P_VALUE  => STRINGIFY(P_VALUE) );
    END IF;
END WRITE;


PROCEDURE WRITE (
    P_VALUE IN CLOB )
IS
BEGIN
    IF P_VALUE IS NULL THEN
        PRAGMA INLINE(WRITE, 'YES');
        WRITE (
            P_VALUE => TO_CHAR(NULL) );
    ELSE
        PRAGMA INLINE(WRITE_RAW, 'YES');
        WRITE_RAW (
            P_VALUE => '"',
            P_DONE  => FALSE );
        FINISH_WRITE_CLOB (
            P_VALUE  => P_VALUE );
    END IF;

END WRITE;


PROCEDURE WRITE (
    P_VALUE IN NUMBER )
IS
BEGIN
    PRAGMA INLINE(WRITE_RAW, 'YES');
    PRAGMA INLINE(STRINGIFY, 'YES');
    WRITE_RAW (
        P_VALUE  => STRINGIFY(P_VALUE) );
END WRITE;


PROCEDURE WRITE (
    P_VALUE       IN DATE,
    P_FORMAT      IN VARCHAR2    DEFAULT C_DATE_ISO8601 )
IS
BEGIN
    PRAGMA INLINE(WRITE_RAW, 'YES');
    PRAGMA INLINE(STRINGIFY, 'YES');
    WRITE_RAW (
        P_VALUE  => STRINGIFY (
                        P_VALUE  => P_VALUE,
                        P_FORMAT => P_FORMAT ));
END WRITE;


PROCEDURE WRITE (
    P_VALUE       IN TIMESTAMP,
    P_FORMAT      IN VARCHAR2    DEFAULT C_TIMESTAMP_ISO8601_FF )
IS
BEGIN
    PRAGMA INLINE(WRITE_RAW, 'YES');
    PRAGMA INLINE(STRINGIFY, 'YES');
    WRITE_RAW (
        P_VALUE  => STRINGIFY (
                        P_VALUE  => P_VALUE,
                        P_FORMAT => P_FORMAT ));
END WRITE;


PROCEDURE WRITE (
    P_VALUE       IN TIMESTAMP WITH LOCAL TIME ZONE,
    P_FORMAT      IN VARCHAR2    DEFAULT C_TIMESTAMP_ISO8601_FF_TZR )
IS
BEGIN
    PRAGMA INLINE(WRITE_RAW, 'YES');
    PRAGMA INLINE(STRINGIFY, 'YES');
    WRITE_RAW (
        P_VALUE  => STRINGIFY (
                        P_VALUE  => P_VALUE,
                        P_FORMAT => P_FORMAT ));
END WRITE;


PROCEDURE WRITE (
    P_VALUE       IN TIMESTAMP WITH TIME ZONE,
    P_FORMAT      IN VARCHAR2    DEFAULT C_TIMESTAMP_ISO8601_FF_TZD )
IS
BEGIN
    PRAGMA INLINE(WRITE_RAW, 'YES');
    PRAGMA INLINE(STRINGIFY, 'YES');
    WRITE_RAW (
        P_VALUE  => STRINGIFY (
                        P_VALUE  => P_VALUE,
                        P_FORMAT => P_FORMAT ));
END WRITE;


PROCEDURE WRITE (
    P_VALUE       IN BOOLEAN )
IS
BEGIN
    PRAGMA INLINE(WRITE_RAW, 'YES');
    PRAGMA INLINE(STRINGIFY, 'YES');
    WRITE_RAW (
        P_VALUE  => STRINGIFY(P_VALUE) );
END WRITE;


PROCEDURE DO_WRITE_XMLTYPE (
    P_VALUE       IN SYS.XMLTYPE )
IS
    C_8K          CONSTANT PLS_INTEGER := POWER(2,13);
    C_16K         CONSTANT PLS_INTEGER := POWER(2,14);
    L_TRANSFORMED SYS.XMLTYPE;
    L_VC_VALUE    VARCHAR2(32767);
    L_CLOB_VALUE  CLOB;
    L_LENGTH      PLS_INTEGER;
    L_OFFSET      PLS_INTEGER;
    L_AMOUNT      PLS_INTEGER;
    L_REST        VARCHAR2(20);




    PROCEDURE WRITE_CHUNK (
        P_STR IN VARCHAR2 )
    IS
        L_STR      VARCHAR2(32767);
        L_AMP_POS  PLS_INTEGER;
        L_SEMI_POS PLS_INTEGER;
    BEGIN



        L_STR     := REPLACE(REPLACE(REPLACE(REPLACE(
                         L_REST||P_STR ,
                         '&quot;'      , '"')  ,
                         '&apos;'      , '''') ,
                         '&lt;'        , '<')  ,
                         '&gt;'        , '>');
        L_REST    := NULL;




        L_AMP_POS := INSTR(L_STR, '&', -1);
        IF L_AMP_POS > 0 THEN





            L_SEMI_POS := INSTR(L_STR, ';', L_AMP_POS+1);
            IF L_SEMI_POS = 0 THEN
                L_REST := SUBSTR(L_STR, L_AMP_POS);
                L_STR  := SUBSTR(L_STR, 1, L_AMP_POS-1);
            END IF;



            IF INSTR(L_STR, '&') > 0 THEN
                L_STR := SYS.DBMS_XMLGEN.CONVERT (
                             XMLDATA => L_STR,
                             FLAG    => SYS.DBMS_XMLGEN.ENTITY_DECODE );
            END IF;
        END IF;




        L_STR := REPLACE(REPLACE(REPLACE(REPLACE(REPLACE (
                     L_STR   ,
                     '\'     , '\\')    ,
                     C_CHR7F , '\"')    ,
                     C_CR    , '\r' )   ,
                     C_LF    , '\n' )   ,
                     C_TAB   , '\t' );



        G_WRITER.PRN(L_STR);
    END WRITE_CHUNK;







    FUNCTION GET_CLOB_AND_CLEAR_XML (
        P_XML IN OUT NOCOPY SYS.XMLTYPE )
        RETURN CLOB
    IS
        L_CLOB CLOB;
    BEGIN
        L_CLOB := L_TRANSFORMED.GETCLOBVAL;
        P_XML  := NULL;
        RETURN L_CLOB;
    END GET_CLOB_AND_CLEAR_XML;

BEGIN
    L_TRANSFORMED := P_VALUE.TRANSFORM(GET_XML_TO_JSON);



    BEGIN
        L_VC_VALUE := L_TRANSFORMED.GETSTRINGVAL;
    EXCEPTION WHEN OTHERS THEN
        PRAGMA INLINE(GET_CLOB_AND_CLEAR_XML,'NO');
        L_CLOB_VALUE := GET_CLOB_AND_CLEAR_XML(L_TRANSFORMED);
    END;



    IF L_VC_VALUE IS NOT NULL THEN
        L_LENGTH := LENGTH(L_VC_VALUE);
        IF L_LENGTH < C_16K THEN
            WRITE_CHUNK(L_VC_VALUE);
        ELSE
            WRITE_CHUNK(SUBSTR(L_VC_VALUE, 1, C_16K-1));
            WRITE_CHUNK(SUBSTR(L_VC_VALUE, C_16K));
        END IF;
    ELSE
        WHILE NEXT_CHUNK (
                  P_STR    => L_CLOB_VALUE,
                  P_CHUNK  => L_VC_VALUE,
                  P_OFFSET => L_OFFSET,
                  P_AMOUNT => C_8K-1 )
        LOOP
            WRITE_CHUNK(L_VC_VALUE);
        END LOOP;
    END IF;

    IF L_REST IS NOT NULL THEN
        RAISE_APPLICATION_ERROR(-20001,'partial xml entity after emitting xmltype :'||L_REST );
    END IF;

    G_WRITER.PRN(C_LF);

    PRAGMA INLINE(DATA_WRITTEN_AT_CURRENT_LEVEL, 'YES');
    DATA_WRITTEN_AT_CURRENT_LEVEL;
END DO_WRITE_XMLTYPE;


PROCEDURE WRITE (
    P_VALUE       IN SYS.XMLTYPE )
IS
    L_INDENT      VARCHAR2(4000);
BEGIN
    IF P_VALUE IS NULL THEN
        WRITE_RAW (
            P_VALUE => TO_CHAR(NULL) );
    ELSE
        PRAGMA INLINE(GET_INDENT, 'YES');
        L_INDENT := GET_INDENT;
        IF L_INDENT IS NOT NULL THEN
            G_WRITER.PRN(L_INDENT);
        END IF;
        DO_WRITE_XMLTYPE (
            P_VALUE => P_VALUE );
    END IF;
END WRITE;


PROCEDURE WRITE_CURSOR (
    P_NAME   IN VARCHAR2,
    P_CURSOR IN OUT NOCOPY SYS_REFCURSOR,
    P_LINKS  IN T_LINKS )
IS
    TYPE T_NLS_FORMAT IS RECORD (
        PARAMETER SYS.NLS_SESSION_PARAMETERS.PARAMETER%TYPE,
        VALUE     SYS.NLS_SESSION_PARAMETERS.VALUE%TYPE );
    TYPE T_NLS_FORMATS IS TABLE OF T_NLS_FORMAT INDEX BY PLS_INTEGER;

    C_TYPECODE_CURSOR         CONSTANT PLS_INTEGER := 102;
    C_TYPECODE_OBJECT         CONSTANT PLS_INTEGER := 109;
    C_TYPECODE_OBJECT_XMLTYPE CONSTANT PLS_INTEGER := 1000001;

    C                  INTEGER;
    L_DESC             SYS.DBMS_SQL.DESC_TAB3;
    L_COUNT            INTEGER;
    L_DATE             DATE;
    L_TIMESTAMP        TIMESTAMP;
    L_TIMESTAMP_TZ     TIMESTAMP WITH TIME ZONE;
    L_TIMESTAMP_LTZ    TIMESTAMP WITH LOCAL TIME ZONE;
    L_NUMBER           NUMBER;
    L_VARCHAR2         VARCHAR2(32767 CHAR);
    L_CLOB             CLOB;
    L_XMLTYPE          SYS.XMLTYPE;
    L_REFCURSOR        SYS_REFCURSOR;
    L_LENGTH           PLS_INTEGER;
    L_NLS_FORMATS      T_NLS_FORMATS;
    L_PREV_NLS_FORMATS T_NLS_FORMATS;

    PROCEDURE ADD_LINK_SUBSTITUTION (
        P_NAME IN VARCHAR2 )
    IS
    BEGIN
        FOR I IN 1 .. G_LINK_SUBSTITUTIONS.COUNT LOOP
            IF G_LINK_SUBSTITUTIONS(I).NAME = P_NAME THEN

                RETURN;
            END IF;
        END LOOP;
        G_LINK_SUBSTITUTIONS(G_LINK_SUBSTITUTIONS.COUNT+1).NAME       := P_NAME;
        G_LINK_SUBSTITUTIONS(G_LINK_SUBSTITUTIONS.COUNT).NAME_PATTERN := '#'||P_NAME||'#';
    END ADD_LINK_SUBSTITUTION;



    PROCEDURE ADD_LINK_SUBSTITUTIONS
    IS
        L_OCCURRENCE PLS_INTEGER;
        L_NAME       VARCHAR2(128);
    BEGIN
        FOR I IN 1 .. P_LINKS.COUNT LOOP
            L_OCCURRENCE := 1;
            LOOP
                L_NAME := REGEXP_SUBSTR (
                              SRCSTR        => P_LINKS(I).HREF,
                              PATTERN       => '#([^#]+)#',
                              OCCURRENCE    => L_OCCURRENCE,
                              SUBEXPRESSION => 1 );
                EXIT WHEN L_NAME IS NULL;

                PRAGMA INLINE(ADD_LINK_SUBSTITUTION, 'YES');
                ADD_LINK_SUBSTITUTION (
                    P_NAME => L_NAME );
                L_OCCURRENCE := L_OCCURRENCE + 1;
            END LOOP;
        END LOOP;
    END ADD_LINK_SUBSTITUTIONS;

    PROCEDURE UPDATE_LINK_SUBSTITUTION (
        P_NAME  IN VARCHAR2,
        P_VALUE IN VARCHAR2 DEFAULT NULL )
    IS
        L_POS PLS_INTEGER := 1;
    BEGIN
        WHILE L_POS <= G_LINK_SUBSTITUTIONS.COUNT LOOP
            IF G_LINK_SUBSTITUTIONS(L_POS).NAME = P_NAME THEN
                G_LINK_SUBSTITUTIONS(L_POS).VAL := P_VALUE;
                EXIT;
            END IF;
            L_POS := L_POS + 1;
        END LOOP;
    END UPDATE_LINK_SUBSTITUTION;

    PROCEDURE SET_NLS_FORMATS (
        P_NLS_FORMATS IN T_NLS_FORMATS )
    IS
    BEGIN
        FOR I IN 1..P_NLS_FORMATS.COUNT LOOP
            SYS.DBMS_SESSION.SET_NLS (
                PARAM => P_NLS_FORMATS(I).PARAMETER,
                VALUE => ENQUOTE_LITERAL(P_NLS_FORMATS(I).VALUE) );
        END LOOP;
    END SET_NLS_FORMATS;

BEGIN



    IF P_LINKS IS NOT NULL THEN
        PRAGMA INLINE(ADD_LINK_SUBSTITUTIONS, 'YES');
        ADD_LINK_SUBSTITUTIONS;
    END IF;



    C := SYS.DBMS_SQL.TO_CURSOR_NUMBER(P_CURSOR);
    SYS.DBMS_SQL.DESCRIBE_COLUMNS3(C, L_COUNT, L_DESC);




    FOR I IN 1 .. L_COUNT LOOP
        IF ( L_DESC(I).COL_TYPE = C_TYPECODE_OBJECT
             AND (   L_DESC(I).COL_SCHEMA_NAME <> 'SYS'
                  OR L_DESC(I).COL_TYPE_NAME   <> 'XMLTYPE'))
           OR L_DESC(I).COL_TYPE = C_TYPECODE_CURSOR
        THEN
            IF P_LINKS IS NOT NULL THEN
                RAISE_APPLICATION_ERROR(-20001,'implementation restriction: nested type and cursor columns not supported' );
            END IF;

            L_REFCURSOR := SYS.DBMS_SQL.TO_REFCURSOR(C);
            BEGIN
                SELECT PARAMETER,
                       VALUE
                  BULK COLLECT INTO L_PREV_NLS_FORMATS
                  FROM SYS.NLS_SESSION_PARAMETERS
                 WHERE PARAMETER IN ( 'NLS_DATE_FORMAT', 'NLS_TIMESTAMP_FORMAT', 'NLS_TIMESTAMP_TZ_FORMAT', 'NLS_NUMERIC_CHARACTERS' );

                L_NLS_FORMATS(1).PARAMETER := 'NLS_DATE_FORMAT';
                L_NLS_FORMATS(1).VALUE     := C_DATE_ISO8601;
                L_NLS_FORMATS(2).PARAMETER := 'NLS_TIMESTAMP_FORMAT';
                L_NLS_FORMATS(2).VALUE     := C_TIMESTAMP_ISO8601_FF;
                L_NLS_FORMATS(3).PARAMETER := 'NLS_TIMESTAMP_TZ_FORMAT';
                L_NLS_FORMATS(3).VALUE     := C_TIMESTAMP_ISO8601_FF_TZD;
                L_NLS_FORMATS(4).PARAMETER := 'NLS_NUMERIC_CHARACTERS';
                L_NLS_FORMATS(4).VALUE     := '.,';
                SET_NLS_FORMATS(L_NLS_FORMATS);

                L_XMLTYPE := SYS.XMLTYPE(L_REFCURSOR);
            EXCEPTION WHEN VALUE_ERROR THEN




                OPEN_ARRAY (
                    P_NAME => P_NAME );
                CLOSE_ARRAY;
                SET_NLS_FORMATS(L_PREV_NLS_FORMATS);
                RETURN;
            END;
            SET_NLS_FORMATS(L_PREV_NLS_FORMATS);

            IF P_NAME IS NOT NULL THEN
                WRITE(P_NAME, L_XMLTYPE);
            ELSE
                WRITE(L_XMLTYPE);
            END IF;
            RETURN;
        END IF;
    END LOOP;



    FOR I IN 1 .. L_COUNT LOOP
        IF L_DESC(I).COL_TYPE = SYS.DBMS_SQL.DATE_TYPE THEN
            SYS.DBMS_SQL.DEFINE_COLUMN(C, I, L_DATE);
        ELSIF L_DESC(I).COL_TYPE = SYS.DBMS_SQL.TIMESTAMP_TYPE THEN
            SYS.DBMS_SQL.DEFINE_COLUMN(C, I, L_TIMESTAMP);
        ELSIF L_DESC(I).COL_TYPE = SYS.DBMS_SQL.TIMESTAMP_WITH_TZ_TYPE THEN
            SYS.DBMS_SQL.DEFINE_COLUMN(C, I, L_TIMESTAMP_TZ);
        ELSIF L_DESC(I).COL_TYPE = SYS.DBMS_SQL.TIMESTAMP_WITH_LOCAL_TZ_TYPE THEN
            SYS.DBMS_SQL.DEFINE_COLUMN(C, I, L_TIMESTAMP_LTZ);
        ELSIF L_DESC(I).COL_TYPE IN ( SYS.DBMS_SQL.NUMBER_TYPE,
                                      SYS.DBMS_SQL.BINARY_FLOAT_TYPE,
                                      SYS.DBMS_SQL.BINARY_BOUBLE_TYPE ) 
        THEN
            SYS.DBMS_SQL.DEFINE_COLUMN(C, I, L_NUMBER);
        ELSIF L_DESC(I).COL_TYPE = C_TYPECODE_OBJECT THEN
            IF L_DESC(I).COL_SCHEMA_NAME = 'SYS'
               AND L_DESC(I).COL_TYPE_NAME   = 'XMLTYPE'
            THEN



                L_DESC(I).COL_TYPE := C_TYPECODE_OBJECT_XMLTYPE;
                SYS.DBMS_SQL.DEFINE_COLUMN(C, I, L_XMLTYPE);
            END IF;
        ELSIF L_DESC(I).COL_TYPE = SYS.DBMS_SQL.CLOB_TYPE THEN
            SYS.DBMS_SQL.DEFINE_COLUMN(C, I, L_CLOB);
        ELSE
            SYS.DBMS_SQL.DEFINE_COLUMN(C, I, L_VARCHAR2, 32767);
        END IF;




        L_DESC(I).COL_NULL_OK := FALSE;
        FOR J IN 1 .. G_LINK_SUBSTITUTIONS.COUNT LOOP
            IF L_DESC(I).COL_NAME = G_LINK_SUBSTITUTIONS(J).NAME THEN
                L_DESC(I).COL_NULL_OK := TRUE;
                EXIT;
            END IF;
        END LOOP;
    END LOOP;



    OPEN_ARRAY (
        P_NAME => P_NAME );



    WHILE SYS.DBMS_SQL.FETCH_ROWS(C) > 0 LOOP



        OPEN_OBJECT;






        FOR I IN 1 .. L_COUNT LOOP
            IF L_DESC(I).COL_TYPE = SYS.DBMS_SQL.DATE_TYPE THEN
                SYS.DBMS_SQL.COLUMN_VALUE(C, I, L_DATE);
                IF L_DATE IS NOT NULL THEN
                    WRITE(L_DESC(I).COL_NAME, L_DATE);
                END IF;
                IF L_DESC(I).COL_NULL_OK THEN
                    PRAGMA INLINE(UPDATE_LINK_SUBSTITUTION, 'YES');
                    UPDATE_LINK_SUBSTITUTION (
                        P_NAME  => L_DESC(I).COL_NAME,
                        P_VALUE => TO_CHAR(L_DATE, C_DATE_ISO8601) );
                END IF;
            ELSIF L_DESC(I).COL_TYPE = SYS.DBMS_SQL.TIMESTAMP_TYPE THEN
                SYS.DBMS_SQL.COLUMN_VALUE(C, I, L_TIMESTAMP);
                IF L_TIMESTAMP IS NOT NULL THEN
                    WRITE(L_DESC(I).COL_NAME, L_TIMESTAMP);
                END IF;
                IF L_DESC(I).COL_NULL_OK THEN
                    PRAGMA INLINE(UPDATE_LINK_SUBSTITUTION, 'YES');
                    UPDATE_LINK_SUBSTITUTION (
                        P_NAME  => L_DESC(I).COL_NAME,
                        P_VALUE => TO_CHAR(L_TIMESTAMP, C_TIMESTAMP_ISO8601_FF) );
                END IF;
            ELSIF L_DESC(I).COL_TYPE = SYS.DBMS_SQL.TIMESTAMP_WITH_TZ_TYPE THEN
                SYS.DBMS_SQL.COLUMN_VALUE(C, I, L_TIMESTAMP_TZ);
                IF L_TIMESTAMP_TZ IS NOT NULL THEN
                    WRITE(L_DESC(I).COL_NAME, L_TIMESTAMP_TZ);
                END IF;
                IF L_DESC(I).COL_NULL_OK THEN
                    PRAGMA INLINE(UPDATE_LINK_SUBSTITUTION, 'YES');
                    UPDATE_LINK_SUBSTITUTION (
                        P_NAME  => L_DESC(I).COL_NAME,
                        P_VALUE => TO_CHAR(L_TIMESTAMP_TZ, C_TIMESTAMP_ISO8601_FF_TZD) );
                END IF;
            ELSIF L_DESC(I).COL_TYPE = SYS.DBMS_SQL.TIMESTAMP_WITH_LOCAL_TZ_TYPE THEN
                SYS.DBMS_SQL.COLUMN_VALUE(C, I, L_TIMESTAMP_LTZ);
                IF L_TIMESTAMP_LTZ IS NOT NULL THEN
                    WRITE(L_DESC(I).COL_NAME, L_TIMESTAMP_LTZ);
                END IF;
                IF L_DESC(I).COL_NULL_OK THEN
                    PRAGMA INLINE(UPDATE_LINK_SUBSTITUTION, 'YES');
                    UPDATE_LINK_SUBSTITUTION (
                        P_NAME  => L_DESC(I).COL_NAME,
                        P_VALUE => TRIM( BOTH '"' FROM STRINGIFY(L_TIMESTAMP_LTZ)) );
                END IF;
            ELSIF L_DESC(I).COL_TYPE IN ( SYS.DBMS_SQL.NUMBER_TYPE,
                                          SYS.DBMS_SQL.BINARY_FLOAT_TYPE,
                                          SYS.DBMS_SQL.BINARY_BOUBLE_TYPE ) 
            THEN
                SYS.DBMS_SQL.COLUMN_VALUE(C, I, L_NUMBER);
                IF L_NUMBER IS NOT NULL THEN
                    WRITE(L_DESC(I).COL_NAME, L_NUMBER);
                END IF;
                IF L_DESC(I).COL_NULL_OK THEN
                    PRAGMA INLINE(UPDATE_LINK_SUBSTITUTION, 'YES');
                    UPDATE_LINK_SUBSTITUTION (
                        P_NAME  => L_DESC(I).COL_NAME,
                        P_VALUE => STRINGIFY(L_NUMBER) );
                END IF;
            ELSIF L_DESC(I).COL_TYPE = C_TYPECODE_OBJECT_XMLTYPE THEN
                SYS.DBMS_SQL.COLUMN_VALUE(C, I, L_XMLTYPE);
                IF L_XMLTYPE IS NOT NULL THEN
                    WRITE(L_DESC(I).COL_NAME, L_XMLTYPE);
                END IF;
            ELSIF L_DESC(I).COL_TYPE = SYS.DBMS_SQL.CLOB_TYPE THEN
                SYS.DBMS_SQL.COLUMN_VALUE(C, I, L_CLOB);
                WRITE(L_DESC(I).COL_NAME, L_CLOB);
            ELSE
                SYS.DBMS_SQL.COLUMN_VALUE(C, I, L_VARCHAR2);
                L_LENGTH := LENGTH(L_VARCHAR2);
                IF L_LENGTH = 4 AND UPPER(L_VARCHAR2) = 'TRUE' THEN
                    WRITE(L_DESC(I).COL_NAME, TRUE);
                ELSIF L_LENGTH = 5 AND UPPER(L_VARCHAR2) = 'FALSE' THEN
                    WRITE(L_DESC(I).COL_NAME, FALSE);
                ELSIF L_VARCHAR2 IS NOT NULL THEN
                    WRITE(L_DESC(I).COL_NAME, L_VARCHAR2);
                END IF;
                IF L_DESC(I).COL_NULL_OK THEN
                    PRAGMA INLINE(UPDATE_LINK_SUBSTITUTION, 'YES');
                    UPDATE_LINK_SUBSTITUTION (
                        P_NAME  => L_DESC(I).COL_NAME,
                        P_VALUE => L_VARCHAR2 );
                END IF;
            END IF;
        END LOOP;

        IF P_LINKS IS NOT NULL THEN
            WRITE_LINKS (
                P_LINKS => P_LINKS );
        END IF;

        CLOSE_OBJECT;
    END LOOP;



    CLOSE_ARRAY;

    SYS.DBMS_SQL.CLOSE_CURSOR(C);

    IF P_LINKS IS NOT NULL THEN
        G_LINK_SUBSTITUTIONS.DELETE;
    END IF;
EXCEPTION WHEN OTHERS THEN
    IF SYS.DBMS_SQL.IS_OPEN(C) THEN
        SYS.DBMS_SQL.CLOSE_CURSOR(C);
    END IF;
    SET_NLS_FORMATS(L_PREV_NLS_FORMATS);
    RAISE;
END WRITE_CURSOR;


PROCEDURE WRITE (
    P_CURSOR      IN OUT NOCOPY SYS_REFCURSOR )
IS

BEGIN
    WRITE_CURSOR (
        P_NAME   => NULL,
        P_CURSOR => P_CURSOR,
        P_LINKS  => NULL );
END WRITE;


PROCEDURE WRITE (
    P_NAME        IN VARCHAR2,
    P_VALUE       IN VARCHAR2,
    P_WRITE_NULL  IN BOOLEAN DEFAULT FALSE )
IS
    L_LENGTH PLS_INTEGER := LENGTH(P_VALUE);
BEGIN
    IF L_LENGTH > C_STRINGIFY_LENGTH THEN
        PRAGMA INLINE(WRITE_RAW_NAME, 'YES');
        WRITE_RAW_NAME (
            P_NAME => P_NAME );

        G_WRITER.PRN('"');

        PRAGMA INLINE(FINISH_WRITE_LONG_VARCHAR2, 'YES');
        FINISH_WRITE_LONG_VARCHAR2 (
            P_VALUE  => P_VALUE,
            P_LENGTH => L_LENGTH );
    ELSIF L_LENGTH > 0 THEN
        PRAGMA INLINE(WRITE_RAW, 'YES');
        PRAGMA INLINE(STRINGIFY, 'YES');
        WRITE_RAW (
            P_NAME   => P_NAME,
            P_VALUE  => STRINGIFY(P_VALUE));
    ELSIF P_WRITE_NULL THEN
        PRAGMA INLINE(WRITE_RAW, 'YES');
        WRITE_RAW (
            P_NAME   => P_NAME,
            P_VALUE  => 'null' );
    END IF;
END WRITE;


PROCEDURE WRITE (
    P_NAME        IN VARCHAR2,
    P_VALUE       IN CLOB,
    P_WRITE_NULL  IN BOOLEAN DEFAULT FALSE )
IS
BEGIN
    IF P_VALUE IS NOT NULL THEN
        PRAGMA INLINE(WRITE_RAW_NAME, 'YES');
        WRITE_RAW_NAME (
            P_NAME => P_NAME );

        G_WRITER.PRN('"');

        PRAGMA INLINE(FINISH_WRITE_CLOB, 'YES');
        FINISH_WRITE_CLOB (
            P_VALUE  => P_VALUE );
    ELSIF P_WRITE_NULL THEN
        PRAGMA INLINE(WRITE_RAW, 'YES');
        WRITE_RAW (
            P_NAME  => P_NAME,
            P_VALUE => 'null' );
    END IF;
END WRITE;


PROCEDURE WRITE (
    P_NAME         IN VARCHAR2,
    P_VALUE        IN NUMBER,
    P_WRITE_NULL  IN BOOLEAN DEFAULT FALSE )
IS
BEGIN
    IF P_VALUE IS NOT NULL OR P_WRITE_NULL THEN
        PRAGMA INLINE(WRITE_RAW, 'YES');
        PRAGMA INLINE(STRINGIFY, 'YES');
        WRITE_RAW (
            P_NAME   => P_NAME,
            P_VALUE  => STRINGIFY(P_VALUE));
    END IF;
END WRITE;


PROCEDURE WRITE (
    P_NAME        IN VARCHAR2,
    P_VALUE       IN DATE,
    P_FORMAT      IN VARCHAR2    DEFAULT C_DATE_ISO8601,
    P_WRITE_NULL  IN BOOLEAN DEFAULT FALSE )
IS
BEGIN
    IF P_VALUE IS NOT NULL OR P_WRITE_NULL THEN
        PRAGMA INLINE(WRITE_RAW, 'YES');
        PRAGMA INLINE(STRINGIFY, 'YES');
        WRITE_RAW (
            P_NAME   => P_NAME,
            P_VALUE  => STRINGIFY (
                            P_VALUE  => P_VALUE,
                            P_FORMAT => P_FORMAT ));
    END IF;
END WRITE;


PROCEDURE WRITE (
    P_NAME        IN VARCHAR2,
    P_VALUE       IN TIMESTAMP,
    P_FORMAT      IN VARCHAR2    DEFAULT C_TIMESTAMP_ISO8601_FF,
    P_WRITE_NULL  IN BOOLEAN DEFAULT FALSE )
IS
BEGIN
    IF P_VALUE IS NOT NULL OR P_WRITE_NULL THEN
        PRAGMA INLINE(WRITE_RAW, 'YES');
        PRAGMA INLINE(STRINGIFY, 'YES');
        WRITE_RAW (
            P_NAME   => P_NAME,
            P_VALUE  => STRINGIFY (
                            P_VALUE  => P_VALUE,
                            P_FORMAT => P_FORMAT ));
    END IF;
END WRITE;


PROCEDURE WRITE (
    P_NAME        IN VARCHAR2,
    P_VALUE       IN TIMESTAMP WITH LOCAL TIME ZONE,
    P_FORMAT      IN VARCHAR2    DEFAULT C_TIMESTAMP_ISO8601_FF_TZR,
    P_WRITE_NULL  IN BOOLEAN DEFAULT FALSE )
IS
BEGIN
    IF P_VALUE IS NOT NULL OR P_WRITE_NULL THEN
        PRAGMA INLINE(WRITE_RAW, 'YES');
        PRAGMA INLINE(STRINGIFY, 'YES');
        WRITE_RAW (
            P_NAME   => P_NAME,
            P_VALUE  => STRINGIFY (
                            P_VALUE  => P_VALUE,
                            P_FORMAT => P_FORMAT ));
    END IF;
END WRITE;


PROCEDURE WRITE (
    P_NAME        IN VARCHAR2,
    P_VALUE       IN TIMESTAMP WITH TIME ZONE,
    P_FORMAT      IN VARCHAR2    DEFAULT C_TIMESTAMP_ISO8601_FF_TZD,
    P_WRITE_NULL  IN BOOLEAN DEFAULT FALSE )
IS
BEGIN
    IF P_VALUE IS NOT NULL OR P_WRITE_NULL THEN
        PRAGMA INLINE(WRITE_RAW, 'YES');
        PRAGMA INLINE(STRINGIFY, 'YES');
        WRITE_RAW (
            P_NAME   => P_NAME,
            P_VALUE  => STRINGIFY (
                            P_VALUE  => P_VALUE,
                            P_FORMAT => P_FORMAT ));
    END IF;
END WRITE;


PROCEDURE WRITE (
    P_NAME        IN VARCHAR2,
    P_VALUE       IN BOOLEAN,
    P_WRITE_NULL  IN BOOLEAN DEFAULT FALSE )
IS
BEGIN
    IF P_VALUE IS NOT NULL OR P_WRITE_NULL THEN
        PRAGMA INLINE(WRITE_RAW, 'YES');
        PRAGMA INLINE(STRINGIFY, 'YES');
        WRITE_RAW (
            P_NAME   => P_NAME,
            P_VALUE  => STRINGIFY(P_VALUE));
    END IF;
END WRITE;


PROCEDURE WRITE (
    P_NAME        IN VARCHAR2,
    P_VALUES      IN apx_T_VARCHAR2,
    P_WRITE_NULL  IN BOOLEAN DEFAULT FALSE )
IS
BEGIN
    IF P_VALUES.COUNT > 0 OR P_WRITE_NULL THEN
        OPEN_ARRAY( P_NAME );
        FOR I IN 1 .. P_VALUES.COUNT LOOP
            PRAGMA INLINE(WRITE, 'YES');
            WRITE( P_VALUES(I) );
        END LOOP;
        CLOSE_ARRAY;
    END IF;
END WRITE;


PROCEDURE WRITE (
    P_NAME        IN VARCHAR2,
    P_VALUES      IN apx_T_NUMBER,
    P_WRITE_NULL  IN BOOLEAN DEFAULT FALSE )
IS
BEGIN
    IF P_VALUES.COUNT > 0 OR P_WRITE_NULL THEN
        OPEN_ARRAY( P_NAME );
        FOR I IN 1 .. P_VALUES.COUNT LOOP
            PRAGMA INLINE(WRITE, 'YES');
            WRITE( P_VALUES(I) );
        END LOOP;
        CLOSE_ARRAY;
    END IF;
END WRITE;


PROCEDURE WRITE (
    P_NAME        IN VARCHAR2,
    P_CURSOR      IN OUT NOCOPY SYS_REFCURSOR )
IS
BEGIN
    WRITE_CURSOR (
        P_NAME   => P_NAME,
        P_CURSOR => P_CURSOR,
        P_LINKS  => NULL );
END WRITE;


PROCEDURE WRITE (
    P_NAME        IN VARCHAR2,
    P_VALUE       IN SYS.XMLTYPE,
    P_WRITE_NULL  IN BOOLEAN DEFAULT FALSE )
IS
BEGIN
    IF P_VALUE IS NOT NULL THEN
        WRITE_RAW_NAME(P_NAME);
        DO_WRITE_XMLTYPE (
            P_VALUE => P_VALUE );
    ELSIF P_WRITE_NULL THEN
        WRITE_RAW (
            P_NAME  => P_NAME,
            P_VALUE => 'null' );
    END IF;
END WRITE;


PROCEDURE WRITE (
    P_VALUES      IN T_VALUES,
    P_PATH        IN VARCHAR2 DEFAULT '.',
    P0            IN VARCHAR2 DEFAULT NULL,
    P1            IN VARCHAR2 DEFAULT NULL,
    P2            IN VARCHAR2 DEFAULT NULL,
    P3            IN VARCHAR2 DEFAULT NULL,
    P4            IN VARCHAR2 DEFAULT NULL )
IS
    L_PATH  VARCHAR2(32767);
    L_VALUE T_VALUE;
BEGIN
    IF P0 IS NULL THEN
        L_PATH := P_PATH;
    ELSE
        L_PATH := FORMAT(P_PATH, P0, P1, P2, P3, P4);
    END IF;

    L_VALUE := P_VALUES(L_PATH);
    CASE L_VALUE.KIND
      WHEN C_NULL     THEN IF G_OUTPUT.INDENT > 0 THEN
                               WRITE(P_VALUE => TO_CHAR(NULL));
                           END IF;
      WHEN C_TRUE     THEN WRITE(TRUE);
      WHEN C_FALSE    THEN WRITE(FALSE);
      WHEN C_NUMBER   THEN WRITE(L_VALUE.NUMBER_VALUE);
      WHEN C_VARCHAR2 THEN WRITE(P_VALUE => L_VALUE.VARCHAR2_VALUE);
      WHEN C_CLOB     THEN WRITE(P_VALUE => L_VALUE.CLOB_VALUE);
      WHEN C_OBJECT   THEN OPEN_OBJECT;
                           FOR I IN 1 .. L_VALUE.OBJECT_MEMBERS.COUNT LOOP
                               WRITE (
                                   P_NAME      => L_VALUE.OBJECT_MEMBERS(I),
                                   P_VALUES    => P_VALUES,
                                   P_PATH      => CASE WHEN L_PATH='.'
                                                    THEN L_VALUE.OBJECT_MEMBERS(I)
                                                    ELSE L_PATH||'.'||L_VALUE.OBJECT_MEMBERS(I)
                                                  END );
                           END LOOP;
                           CLOSE_OBJECT;
      WHEN C_ARRAY   THEN OPEN_ARRAY;
                           FOR I IN 1 .. L_VALUE.NUMBER_VALUE LOOP
                               WRITE (
                                   P_VALUES    => P_VALUES,
                                   P_PATH      => NULLIF(L_PATH,'.')||'['||I||']' );
                           END LOOP;
                           CLOSE_ARRAY;
    END CASE;
END WRITE;


PROCEDURE WRITE (
    P_NAME        IN VARCHAR2,
    P_VALUES      IN T_VALUES,
    P_PATH        IN VARCHAR2 DEFAULT '.',
    P0            IN VARCHAR2 DEFAULT NULL,
    P1            IN VARCHAR2 DEFAULT NULL,
    P2            IN VARCHAR2 DEFAULT NULL,
    P3            IN VARCHAR2 DEFAULT NULL,
    P4            IN VARCHAR2 DEFAULT NULL,
    P_WRITE_NULL  IN BOOLEAN DEFAULT FALSE )
IS
    L_PATH  VARCHAR2(32767);
    L_VALUE T_VALUE;
BEGIN
    IF P0 IS NULL THEN
        L_PATH := P_PATH;
    ELSE
        L_PATH := FORMAT(P_PATH, P0, P1, P2, P3, P4);
    END IF;

    L_VALUE := P_VALUES(L_PATH);
    CASE L_VALUE.KIND
      WHEN C_NULL     THEN IF G_OUTPUT.INDENT > 0 OR P_WRITE_NULL THEN
                               WRITE(P_NAME,P_VALUE => TO_CHAR(NULL));
                           END IF;
      WHEN C_TRUE     THEN WRITE(P_NAME,TRUE);
      WHEN C_FALSE    THEN WRITE(P_NAME,FALSE);
      WHEN C_NUMBER   THEN WRITE(P_NAME,L_VALUE.NUMBER_VALUE);
      WHEN C_VARCHAR2 THEN WRITE(P_NAME,L_VALUE.VARCHAR2_VALUE);
      WHEN C_CLOB     THEN WRITE(P_NAME,L_VALUE.CLOB_VALUE);
      WHEN C_OBJECT   THEN OPEN_OBJECT(P_NAME);
                           FOR I IN 1 .. L_VALUE.OBJECT_MEMBERS.COUNT LOOP
                               WRITE (
                                   P_NAME      => L_VALUE.OBJECT_MEMBERS(I),
                                   P_VALUES    => P_VALUES,
                                   P_PATH      => CASE WHEN L_PATH='.'
                                                    THEN L_VALUE.OBJECT_MEMBERS(I)
                                                    ELSE L_PATH||'.'||L_VALUE.OBJECT_MEMBERS(I)
                                                  END );
                           END LOOP;
                           CLOSE_OBJECT;
      WHEN C_ARRAY   THEN OPEN_ARRAY(P_NAME);
                           FOR I IN 1 .. L_VALUE.NUMBER_VALUE LOOP
                               WRITE (
                                   P_VALUES    => P_VALUES,
                                   P_PATH      => NULLIF(L_PATH,'.')||'['||I||']' );
                           END LOOP;
                           CLOSE_ARRAY;
    END CASE;
END WRITE;








FUNCTION LINK (
    P_HREF       IN VARCHAR2,
    P_REL        IN VARCHAR2,
    P_TEMPLATED  IN BOOLEAN  DEFAULT NULL,
    P_MEDIA_TYPE IN VARCHAR2 DEFAULT NULL,
    P_METHOD     IN VARCHAR2 DEFAULT NULL,
    P_PROFILE    IN VARCHAR2 DEFAULT NULL )
    RETURN T_LINK
IS
    L_LINK T_LINK;
BEGIN
    L_LINK.HREF       := P_HREF;
    L_LINK.REL        := P_REL;
    L_LINK.TEMPLATED  := P_TEMPLATED;
    L_LINK.MEDIA_TYPE := P_MEDIA_TYPE;
    L_LINK.METHOD     := P_METHOD;
    L_LINK.PROFILE    := P_PROFILE;
    RETURN L_LINK;
END LINK;


PROCEDURE WRITE_LINKS (
    P_LINKS IN T_LINKS )
IS
    L_HREF VARCHAR2(32767);
BEGIN
    IF P_LINKS IS NOT NULL
       AND P_LINKS.COUNT > 0
    THEN
        OPEN_ARRAY('links');
        FOR I IN 1 .. P_LINKS.COUNT LOOP
            L_HREF := P_LINKS(I).HREF;
            FOR J IN 1 .. G_LINK_SUBSTITUTIONS.COUNT LOOP
                L_HREF := REPLACE(L_HREF, G_LINK_SUBSTITUTIONS(J).NAME_PATTERN, G_LINK_SUBSTITUTIONS(J).VAL);
            END LOOP;
            OPEN_OBJECT;
            WRITE('href'      , L_HREF);
            WRITE('rel'       , P_LINKS(I).REL);
            WRITE('templated' , P_LINKS(I).TEMPLATED);
            WRITE('mediaType' , P_LINKS(I).MEDIA_TYPE);
            WRITE('method'    , P_LINKS(I).METHOD);
            WRITE('profile'   , P_LINKS(I).PROFILE);
            CLOSE_OBJECT;
        END LOOP;
        CLOSE_ARRAY;
    END IF;
END WRITE_LINKS;


PROCEDURE WRITE_ITEMS (
    P_ITEMS      IN OUT NOCOPY SYS_REFCURSOR,
    P_ITEM_LINKS IN            T_LINKS DEFAULT NULL,
    P_LINKS      IN            T_LINKS DEFAULT NULL )
IS
    L_ENCLOSE_IN_OBJECT BOOLEAN := G_OUTPUT.NESTING_LEVEL = 0;
BEGIN

    IF L_ENCLOSE_IN_OBJECT THEN
        OPEN_OBJECT;
    END IF;

    WRITE_CURSOR (
        P_NAME   => 'items',
        P_CURSOR => P_ITEMS,
        P_LINKS  => P_ITEM_LINKS );
    WRITE_LINKS (
        P_LINKS => P_LINKS );

    IF L_ENCLOSE_IN_OBJECT THEN
        CLOSE_OBJECT;
    END IF;
END WRITE_ITEMS;

END apx_JSON;
/
