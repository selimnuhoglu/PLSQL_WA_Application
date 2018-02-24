BEGIN
  -- delete tables
  BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE selim_application';
    EXECUTE IMMEDIATE 'DROP TABLE selim_application_conf';
    EXECUTE IMMEDIATE 'DROP TABLE selim_application_log';
  EXCEPTION
    WHEN OTHERS THEN
      dbms_output.put_line('TABLE ERROR...');
      dbms_output.put_line(SQLERRM);
  END;
  
  -- delete job
  BEGIN
    dbms_scheduler.drop_job(job_name => 'SELIM_APPLICATION_JOB');
    dbms_scheduler.drop_job(job_name => 'SELIM_APPLICATION_INSERT_JOB');
  EXCEPTION
    WHEN OTHERS THEN
      dbms_output.put_line('SCHEDULER ERROR...');
      dbms_output.put_line(SQLERRM);
  END;

  -- delecte packages
  BEGIN
    EXECUTE IMMEDIATE 'DROP PACKAGE application';
    EXECUTE IMMEDIATE 'DROP PROCEDURE insert_operations';
  EXCEPTION
    WHEN OTHERS THEN
      dbms_output.put_line('PACKAGE ERROR...');
      dbms_output.put_line(SQLERRM);
  END;
END;
/
