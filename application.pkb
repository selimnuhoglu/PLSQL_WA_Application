CREATE OR REPLACE PACKAGE BODY application AS

cs_RETRY_COUNT     CONSTANT VARCHAR2(30) := 'RETRY_COUNT';

cs_STATUS_RETRY    CONSTANT VARCHAR2(1)  := 'R';
cs_STATUS_FAIL     CONSTANT VARCHAR2(1)  := 'F';
cs_STATUS_SUCCESS  CONSTANT VARCHAR2(1)  := 'S';
cs_STATUS_NEW      CONSTANT VARCHAR2(1)  := 'N';

cd_ID_LIST_DELIMITER  CONSTANT  VARCHAR2(1)  := ',';

TYPE T_CONFIGURATION IS RECORD
  (
    retry_count  NUMBER
  );
    
gt_Configuration T_CONFIGURATION;
  
  PROCEDURE i_SelimApplicationLog(pid_StartDate       selim_application_log.start_date%TYPE,
                                  pid_EndDate         selim_application_log.end_date%TYPE,
                                  pin_OperationCount  selim_application_log.operation_count%TYPE,
                                  pis_Channel         selim_application_log.channel%TYPE) 
    IS
      vn_logId  selim_application_log.log_id%TYPE;
  BEGIN   
    SELECT nvl(MAX(log_id) + 1, 1) INTO vn_logId FROM selim_application_log;
    
		INSERT INTO selim_application_log(log_id, start_date, end_date, elapsed_time, operation_count, channel) 
    VALUES (vn_logId, pid_StartDate, pid_EndDate, (to_number(pid_EndDate - pid_StartDate)*24*60*60), pin_OperationCount, pis_Channel);
    
    COMMIT;
    
  EXCEPTION
    WHEN OTHERS THEN
      dbms_output.put_line(SQLERRM);
      NULL;
  END i_SelimApplicationLog;

  PROCEDURE u_SelimApplication(pin_Id              selim_application.id%TYPE,
                               pin_Result          selim_application.result%TYPE,
                               pic_XmlResponse     selim_application.xml_response%TYPE,
                               pin_RetryCount      selim_application.retry_count%TYPE,
                               pis_Status          selim_application.status%TYPE,
                               pis_HttpStatusCode  selim_application.http_status_code%TYPE,
                               pid_ModifyDate      selim_application.modify_date%TYPE,
                               pid_OperationStart  selim_application.operation_start_ts%TYPE,
                               pid_OperationEnd    selim_application.operation_end_ts%TYPE,
                               pin_ProcessTime     selim_application.process_time%TYPE,
                               pis_ModifyUser      selim_application.modify_user%TYPE)
    IS
  BEGIN
    UPDATE selim_application s
       SET s.result = pin_Result,
           s.xml_response = pic_XmlResponse,
           s.retry_count = pin_RetryCount,
           s.status = pis_Status,
           s.http_status_code = pis_HttpStatusCode,
           s.modify_date = pid_ModifyDate,
           s.operation_start_ts = pid_OperationStart,
           s.operation_end_ts = pid_OperationEnd,
           s.process_time = pin_ProcessTime,
           s.modify_user = pis_ModifyUser
     WHERE s.id = pin_Id; 
       
     COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      dbms_output.put_line('ERROR OCCURED.....');
      dbms_output.put_line('DETAILS...........');
      dbms_output.put_line(SQLERRM);
  END u_SelimApplication;
  
  PROCEDURE u_SelimApplication (pin_RetryCount  selim_application.retry_count%TYPE,
                                pis_ModifyUser  selim_application.modify_user%TYPE)
    IS
  BEGIN
    UPDATE selim_application s
			 SET s.status = cs_STATUS_FAIL,
           s.modify_user = pis_ModifyUser
		 WHERE s.retry_count >= pin_RetryCount
			 AND s.status = cs_STATUS_RETRY;
       
     COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      dbms_output.put_line('ERROR OCCURED.....');
      dbms_output.put_line('DETAILS...........');
      dbms_output.put_line(SQLERRM);
  END u_SelimApplication;
  
	PROCEDURE ExecuteWebService
	(
		pin_Id          NUMBER,
		pin_Number_1    NUMBER,
		pin_Number_2    NUMBER,
		pis_Operation   VARCHAR2,
		pon_Result      OUT NUMBER,
		pos_StatusCode  OUT VARCHAR2,
		poc_XmlResponse OUT CLOB
	)
   IS
     vt_Req           UTL_HTTP.req;
     vt_Resp          UTL_HTTP.resp;
     vs_SoapEnvelope  VARCHAR2 (32000) := '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns="http://tempuri.org/">
                                              <soapenv:Header/>
                                              <soapenv:Body>
                                                 <' || pis_Operation || '>
                                                    <intA>' || pin_Number_1 || '</intA>' ||
                                                    '<intB>' || pin_Number_2 || '</intB>' ||
                                                 '</' || pis_Operation || '>
                                              </soapenv:Body>
                                           </soapenv:Envelope>';
     
     vc_SoapRequest    CLOB;
     vc_SoapResponse   CLOB;
     vn_BufferSize     NUMBER (10) := 512;
     vs_SubstringMsg   VARCHAR2 (512);
     vs_Buffer         VARCHAR2 (32767);
     vb_EOB            BOOLEAN := FALSE;
     vs_HttpTargetUrl  VARCHAR2 (30000) := 'http://www.dneonline.com/calculator.asmx?wsdl';
     vn_Result         NUMBER;
     vs_Status         VARCHAR2(1);
     
  BEGIN
     UTL_TCP.close_all_connections;
     vt_Req := UTL_HTTP.begin_request (vs_HttpTargetUrl, 'POST', 'HTTP/1.1');
     UTL_HTTP.set_header (vt_Req, 'Content-Type', 'text/xml;charset=UTF-8');
     UTL_HTTP.set_header (vt_Req, 'SOAPAction', '"http://tempuri.org/' || pis_Operation || '"');
     UTL_HTTP.set_header (vt_Req, 'Content-Length', LENGTH (vs_SoapEnvelope));
     UTL_HTTP.set_header (vt_Req, 'User-Agent', 'Mozilla/4.0');
    <<request_loop>>
     FOR i IN 0 .. CEIL (LENGTH (vs_SoapEnvelope) / vn_BufferSize) - 1 LOOP
        vs_SubstringMsg := SUBSTR (vs_SoapEnvelope, i * vn_BufferSize + 1, vn_BufferSize);
        BEGIN
           UTL_HTTP.write_text (vt_Req, vs_SubstringMsg);
        EXCEPTION
           WHEN NO_DATA_FOUND
           THEN
              EXIT request_loop;
        END;
     END LOOP request_loop;

     vt_Resp := UTL_HTTP.get_response (vt_Req);
     DBMS_LOB.createtemporary (vc_SoapResponse, TRUE);
     
     WHILE NOT (vb_EOB)
     LOOP
        BEGIN
          vs_Buffer := NULL;
          UTL_HTTP.read_text (vt_Resp, vs_Buffer, 512);
          IF vs_Buffer IS NOT NULL AND LENGTH (vs_Buffer) > 0 THEN
            DBMS_LOB.writeappend (vc_SoapResponse, LENGTH (vs_Buffer), vs_Buffer);
          END IF;
        EXCEPTION
          WHEN UTL_HTTP.end_of_body THEN
            vb_EOB := TRUE;
        END;
     END LOOP;
     
     BEGIN
       pos_StatusCode   := vt_Resp.status_code;
       pon_Result       := xmltype(vc_SoapResponse).extract('//' || pis_Operation || 'Result/text()', 'xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns="http://tempuri.org/"').getStringVal();
       poc_XmlResponse  := vc_SoapResponse;
     EXCEPTION
       WHEN OTHERS THEN
         poc_XmlResponse  := vc_SoapResponse;
     END ;

     DBMS_LOB.freetemporary (vc_SoapResponse);
     UTL_HTTP.end_response (vt_Resp);
     UTL_TCP.close_all_connections;
     
  EXCEPTION
     WHEN UTL_HTTP.too_many_requests
     THEN
       poc_XmlResponse  := vc_SoapResponse;
       
       dbms_output.put_line('ERROR OCCURED.....');
       dbms_output.put_line('DETAILS...........');
       dbms_output.put_line(SQLERRM);
       UTL_TCP.close_all_connections;
     WHEN utl_http.request_failed
     THEN
       poc_XmlResponse  := vc_SoapResponse;
       
       dbms_output.put_line('ERROR OCCURED.....');
       dbms_output.put_line('DETAILS...........');
       dbms_output.put_line(SQLERRM);
       UTL_TCP.close_all_connections;
     WHEN OTHERS
     THEN
       pos_StatusCode   :=  NULL;
       poc_XmlResponse  := vc_SoapResponse;
       
       dbms_output.put_line('ERROR OCCURED.....');
       dbms_output.put_line('DETAILS...........');
       dbms_output.put_line(SQLERRM);
       UTL_TCP.close_all_connections;
  END ExecuteWebService;

  FUNCTION GetNumberParameter
  (
    pis_ParameterName IN selim_application_conf.PARAMETER_NAME%TYPE
  ) 
  RETURN NUMBER
  IS
     vn_ParameterValueNumber NUMBER;
  BEGIN
		 SELECT parameter_value
		   INTO vn_ParameterValueNumber
		   FROM selim_application_conf
		  WHERE parameter_name = pis_ParameterName;
      
     RETURN vn_ParameterValueNumber;
  
  END GetNumberParameter;
  
  FUNCTION GetSplittedText (pis_ParameterString  VARCHAR2,
                            pis_Delimiter        VARCHAR2,
                            pin_ParameterNo      NUMBER) RETURN VARCHAR2 
   IS
      vn_StartPosition   PLS_INTEGER;
      vn_EndPosition     PLS_INTEGER;
      vs_ParameterValue  VARCHAR2 (1000);
    BEGIN
      IF pin_ParameterNo = 1 THEN
         vn_StartPosition := 0;
      ELSE
         vn_StartPosition := INSTR (pis_ParameterString,
                                    pis_Delimiter,
                                    1,
                                    pin_ParameterNo - 1);
      END IF;

      vn_EndPosition := INSTR (pis_ParameterString,
                               pis_Delimiter,
                               1,
                               pin_ParameterNo);

      IF vn_EndPosition = 0 THEN
         vn_EndPosition := LENGTH (pis_ParameterString) + 1;
      END IF;

      vs_ParameterValue := SUBSTR (pis_ParameterString,
                                   vn_StartPosition + 1,
                                   vn_EndPosition - vn_StartPosition - 1);

      IF INSTR (vs_ParameterValue, pis_Delimiter) > 0 OR (pin_ParameterNo > 1 AND vs_ParameterValue = pis_ParameterString) THEN
         vs_ParameterValue := NULL;
      END IF;

      RETURN vs_ParameterValue;
    END GetSplittedText;
  
  PROCEDURE i_Operations
    (
      pis_InsertUser  selim_application.insert_user%TYPE DEFAULT NULL
    )
  IS
    vn_id                  selim_application.id%TYPE;
    vn_numberA             selim_application.number_a%TYPE;
    vn_numberB             selim_application.number_b%TYPE;
    vs_operation           selim_application.operation%TYPE;
    vn_NumberOfOperations  NUMBER;
    cs_StatusNew           selim_application.status%TYPE := 'N';
    cs_InsertDate          selim_application.insert_date%TYPE := SYSDATE;
    cs_CHANNEL_NAME        selim_application.insert_user%TYPE := 'SYSADM';
    vs_ChannelName         selim_application.insert_user%TYPE;
    
  BEGIN
    SELECT NVL(MAX(ID) + 1, 1) 
      INTO vn_id 
      FROM selim_application;
    
    vn_NumberOfOperations := ceil(dbms_random.value(1,100));
    
    IF pis_InsertUser IS NULL THEN
      vs_ChannelName := cs_CHANNEL_NAME;
    ELSE
      vs_ChannelName := pis_InsertUser;
    END IF;
    
    FOR i IN 1..vn_NumberOfOperations LOOP
      vn_numberA := ceil(dbms_random.value(-1,10));
      vn_numberB := ceil(dbms_random.value(-1,10));
      
			SELECT *
        INTO vs_operation
				FROM (SELECT s.*
								 FROM (SELECT 'Add'
													FROM dual
												UNION ALL
												SELECT 'Subtract'
													FROM dual
												UNION ALL
												SELECT 'Multiply'
													FROM dual
												UNION ALL
												SELECT 'Divide' FROM dual) s
								ORDER BY dbms_random.value)
			 WHERE rownum = 1;

        INSERT INTO selim_application(ID, number_a, number_b, operation, status, insert_date, insert_user) 
        VALUES(vn_id, vn_numberA, vn_numberB, vs_operation, cs_StatusNew, cs_InsertDate, vs_ChannelName);
        
        vn_id := vn_id + 1;
    END LOOP;
    
    COMMIT;
  END i_Operations;
  
  PROCEDURE LoadAppConfiguration  
    IS
  BEGIN   
    gt_Configuration.RETRY_COUNT  := GetNumberParameter(pis_ParameterName => cs_RETRY_COUNT);
  EXCEPTION
    WHEN OTHERS THEN
      dbms_output.put_line(SQLERRM);
      NULL;
  END LoadAppConfiguration;
  
  PROCEDURE ManualExecute (pis_IdList      VARCHAR2, 
                           pis_ModifyUser  selim_application.modify_user%TYPE DEFAULT NULL)
    IS
      vs_Status          selim_application.status%TYPE;
      vs_StatusCode      selim_application.http_status_code%TYPE;
      vc_XmlResponse     selim_application.xml_response%TYPE;
      vn_Result          selim_application.result%TYPE;
      
      vn_RetryCount      NUMBER;
      vd_StartDate       DATE;
      vd_EndDate         DATE;
      vn_OperationCount  NUMBER;
      vs_StatusList      VARCHAR2(30);
      vd_ModifyDate      DATE;
      vt_OperationStart  TIMESTAMP(6);
      vt_OperationEnd    TIMESTAMP(6);
      vn_ProcessTime     NUMBER;
      vs_Id              VARCHAR2(1000);
      vn_IdIndex         NUMBER;
      
      vr_rec             selim_application%ROWTYPE;
      
    BEGIN
      LoadAppConfiguration();
    
      vd_StartDate      := SYSDATE;
      vn_OperationCount := 0;
      vs_StatusList     := ',' || cs_STATUS_NEW || ',' || cs_STATUS_RETRY || ',';

      vn_IdIndex  := 1;
      vs_Id       := GetSplittedText(pis_IdList, cd_ID_LIST_DELIMITER, vn_IdIndex);
      
      WHILE vs_Id IS NOT NULL LOOP
        vt_OperationStart := current_timestamp;
        
        SELECT * INTO vr_rec FROM selim_application WHERE id = vs_Id;

        ExecuteWebService(pin_id          => vr_rec.id, 
                          pin_number_1    => vr_rec.number_a, 
                          pin_number_2    => vr_rec.number_b, 
                          pis_operation   => vr_rec.operation,
                          pon_result      => vn_Result, 
                          pos_statusCode  => vs_StatusCode,
                          poc_xmlResponse => vc_XmlResponse);
        
        vn_OperationCount := vn_OperationCount + 1;
        
        IF vs_StatusCode IS NULL THEN
          vs_Status      := cs_STATUS_RETRY;
          vn_RetryCount  := vr_rec.retry_count + 1;
        ELSIF vs_StatusCode = 200 THEN
          vs_Status      := cs_STATUS_SUCCESS;
          vn_RetryCount  := vr_rec.retry_count + 1;
        ELSE
          vs_Status      := cs_STATUS_RETRY;
          vn_RetryCount  := vr_rec.retry_count + 1;
        END IF;
        
        vd_ModifyDate    := SYSDATE;
        vt_OperationEnd  := current_timestamp;
        vn_ProcessTime   := extract(second from vt_OperationEnd - vt_OperationStart)+(extract(minute from vt_OperationStart - vt_OperationStart)*60);
        
        u_SelimApplication(pin_Id              => vr_rec.id,
                           pin_Result          => vn_Result,
                           pic_XmlResponse     => vc_XmlResponse,
                           pin_RetryCount      => vn_RetryCount,
                           pis_Status          => vs_Status,
                           pis_HttpStatusCode  => vs_StatusCode,
                           pid_ModifyDate      => vd_ModifyDate,
                           pid_OperationStart  => vt_OperationStart,
                           pid_OperationEnd    => vt_OperationEnd,
                           pin_ProcessTime     => vn_ProcessTime,
                           pis_ModifyUser      => pis_ModifyUser);
        	
          vn_IdIndex  := vn_IdIndex + 1;
          vs_Id       := GetSplittedText(pis_IdList, cd_ID_LIST_DELIMITER, vn_IdIndex);
      END LOOP;
      
      -- Set fail operations
      u_SelimApplication(pin_RetryCount => gt_Configuration.retry_count, 
                         pis_ModifyUser => pis_ModifyUser);

      vd_EndDate := SYSDATE; 
      i_SelimApplicationLog(vd_StartDate, vd_EndDate, vn_OperationCount, pis_ModifyUser);

    END ManualExecute;
  
  PROCEDURE Main (pis_ModifyUser  selim_application.modify_user%TYPE DEFAULT NULL)
   IS
   
   CURSOR Operations (pis_StatusList  selim_application.status%TYPE,
                      pin_RetryCount  selim_application.retry_count%TYPE)
    IS
      SELECT s.id, s.number_a, s.number_b, s.operation, s.result, nvl(s.retry_count, 0) AS retry_count
        FROM selim_application s
       WHERE instr(pis_StatusList, ',' || s.status || ',') > 0
         AND nvl(s.retry_count, 0) < pin_RetryCount
       ORDER BY s.id;

    vs_Status          selim_application.status%TYPE;
    vs_StatusCode      selim_application.http_status_code%TYPE;
    vc_XmlResponse     selim_application.xml_response%TYPE;
    vn_Result          selim_application.result%TYPE;
    
    vn_RetryCount      NUMBER;
    vd_StartDate       DATE;
    vd_EndDate         DATE;
    vn_OperationCount  NUMBER;
    vs_StatusList      VARCHAR2(30);
    vd_ModifyDate      DATE;
    vt_OperationStart  TIMESTAMP(6);
    vt_OperationEnd    TIMESTAMP(6);
    vn_ProcessTime     NUMBER;
  BEGIN
    LoadAppConfiguration();
    
    vd_StartDate      := SYSDATE;
    vn_OperationCount := 0;
    vs_StatusList     := ',' || cs_STATUS_NEW || ',' || cs_STATUS_RETRY || ',';

    FOR rec IN Operations(pis_StatusList => vs_StatusList,
                          pin_RetryCount => gt_Configuration.retry_count) LOOP
      
      vt_OperationStart := current_timestamp;

      ExecuteWebService(pin_id          => rec.id, 
                        pin_number_1    => rec.number_a, 
                        pin_number_2    => rec.number_b, 
                        pis_operation   => rec.operation,
                        pon_result      => vn_Result, 
                        pos_statusCode  => vs_StatusCode,
                        poc_xmlResponse => vc_XmlResponse);
      
      vn_OperationCount := vn_OperationCount + 1;
      
      IF vs_StatusCode IS NULL THEN
        vs_Status      := cs_STATUS_RETRY;
        vn_RetryCount  := rec.retry_count + 1;
      ELSIF vs_StatusCode = 200 THEN
        vs_Status      := cs_STATUS_SUCCESS;
        vn_RetryCount  := rec.retry_count + 1;
	    ELSE
        vs_Status      := cs_STATUS_RETRY;
        vn_RetryCount  := rec.retry_count + 1;
      END IF;
      
      vd_ModifyDate    := SYSDATE;
      vt_OperationEnd  := current_timestamp;
      vn_ProcessTime   := extract(second from vt_OperationEnd - vt_OperationStart)+(extract(minute from vt_OperationStart - vt_OperationStart)*60);
      
      u_SelimApplication(pin_Id              => rec.id,
                         pin_Result          => vn_Result,
                         pic_XmlResponse     => vc_XmlResponse,
                         pin_RetryCount      => vn_RetryCount,
                         pis_Status          => vs_Status,
                         pis_HttpStatusCode  => vs_StatusCode,
                         pid_ModifyDate      => vd_ModifyDate,
                         pid_OperationStart  => vt_OperationStart,
                         pid_OperationEnd    => vt_OperationEnd,
                         pin_ProcessTime     => vn_ProcessTime,
                         pis_ModifyUser      => pis_ModifyUser);
    END LOOP;
    
    -- Set fail operations
    u_SelimApplication(pin_RetryCount => gt_Configuration.retry_count,
                       pis_ModifyUser => pis_ModifyUser);

    vd_EndDate := SYSDATE; 
    i_SelimApplicationLog(vd_StartDate, vd_EndDate, vn_OperationCount, pis_ModifyUser);

  END main;
END application;
/
