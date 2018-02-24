BEGIN
	EXECUTE IMMEDIATE 'CREATE TABLE selim_application (ID                  NUMBER, 
                                                     number_a            NUMBER NOT NULL,
                                                     number_b            NUMBER NOT NULL,
                                                     operation           VARCHAR2(10) NOT NULL,
                                                     RESULT              NUMBER DEFAULT NULL,
                                                     xml_response        CLOB,
                                                     retry_count         NUMBER DEFAULT 0,
                                                     status              VARCHAR2(1) DEFAULT NULL,
                                                     http_status_code    VARCHAR2(3) DEFAULT NULL,
                                                     insert_date         DATE, 
                                                     modify_date         DATE,
                                                     operation_start_ts  TIMESTAMP(6),
                                                     operation_end_ts    TIMESTAMP(6),
                                                     process_time        NUMBER,
                                                     insert_user         VARCHAR2(20),
                                                     modify_user         VARCHAR2(20),
                                                     CONSTRAINT selim_application_PK PRIMARY KEY(ID))';

	EXECUTE IMMEDIATE 'CREATE TABLE selim_application_conf( parameter_name   VARCHAR2(30),
                                                          parameter_value  NUMBER,
                                                          data_type        VARCHAR2(10))';

	EXECUTE IMMEDIATE 'CREATE TABLE selim_application_log( log_id           NUMBER, 
                                                         start_date       DATE,
                                                         end_date         DATE, 
                                                         elapsed_time     NUMBER,
                                                         operation_count  NUMBER,
                                                         channel          VARCHAR2(100))';

  -- Konfigürasyon insert örneði. Aþaðýdaki tabloya uygulama konfigürasyonlarý girilebilir. 
	-- Retry_count bir uygulama konfigürasyonudur. Her iþlemin 10 kere tekrar edilmesini saðlar.
	EXECUTE IMMEDIATE 'INSERT INTO selim_application_conf VALUES (''RETRY_COUNT'', 10, ''NUMBER'')';
  
	COMMIT;
  
	-- Comments
	EXECUTE IMMEDIATE 'COMMENT ON column selim_application.id IS ''Primary key of table selim_application''';
	EXECUTE IMMEDIATE 'COMMENT ON column selim_application.number_a IS ''First input of aritmetic operation''';
	EXECUTE IMMEDIATE 'COMMENT ON column selim_application.number_b IS ''Second input of aritmetic operation''';
	EXECUTE IMMEDIATE 'COMMENT ON column selim_application.operation IS ''Operation type''';
	EXECUTE IMMEDIATE 'COMMENT ON column selim_application.result IS ''Aritmetic result of operation''';
	EXECUTE IMMEDIATE 'COMMENT ON column selim_application.xml_response IS ''XML Response of web service request''';
	EXECUTE IMMEDIATE 'COMMENT ON column selim_application.retry_count IS ''Retry count of operation. It should be inserted as zero at first. It is incremented on every working of procedure application.main(). Its limit is specified in column selim_application_conf.retry_count''';
	EXECUTE IMMEDIATE 'COMMENT ON column selim_application.status IS ''Status of operation. S: Operation is processed successfully. F: HTTP Response is not 200 after some retry processes. R: Operation will be retry in next work phase of procedure application.main''';
	EXECUTE IMMEDIATE 'COMMENT ON column selim_application.http_status_code IS ''HTTP Response code which is returned from web service.''';

	-- create job 1
	BEGIN
		DBMS_SCHEDULER.CREATE_JOB(job_name        => 'selim_application_job',
															job_type        => 'PLSQL_BLOCK',
															job_action      => 'BEGIN application.main(); END;',
															start_date      => current_timestamp+1/(24*60*60),
															repeat_interval => 'FREQ=HOURLY',
															end_date        => NULL, 
                              enabled         => TRUE,
															comments        => 'Selim Application');
	EXCEPTION
    WHEN OTHERS THEN
      dbms_output.put_line('DBMS_SCHEDULER ERROR:...');
      dbms_output.put_line(SQLERRM);
	END;

	-- create job 2
	-- Bu job application'ýn çalýþma vakti öncesinde insert yapar. Application da bu insertleri kullanarak iþlemler yapar.
	BEGIN
		DBMS_SCHEDULER.CREATE_JOB(job_name        => 'selim_application_insert_job',
															job_type        => 'PLSQL_BLOCK',
															job_action      => 'BEGIN application.i_Operations(); END;',
															start_date      => current_timestamp+2/(24*60*60),
															repeat_interval => 'FREQ=HOURLY',
															end_date        => NULL, 
                              enabled         => TRUE,
															comments        => 'Selim Application Insertions');
	EXCEPTION
    WHEN OTHERS THEN
      dbms_output.put_line('DBMS_SCHEDULER ERROR:...');
      dbms_output.put_line(SQLERRM);
	END;
  
	EXCEPTION
    WHEN OTHERS THEN
      dbms_output.put_line('TABLE ERROR:...');
      dbms_output.put_line(SQLERRM);
END;
/
