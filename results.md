Traceback (most recent call last):
  File "./script/reevaluate_original_task.py", line 85, in <module>
    process(**vars(parse_cmd_arguments()))
  File "./script/reevaluate_original_task.py", line 73, in process
    pipe, err = p.communicate(results_path)
  File "/usr/lib/python3.6/subprocess.py", line 863, in communicate
    stdout, stderr = self._communicate(input, endtime, timeout)
  File "/usr/lib/python3.6/subprocess.py", line 1534, in _communicate
    ready = selector.select(timeout)
  File "/usr/lib/python3.6/selectors.py", line 376, in select
    fd_event_list = self._poll.poll(timeout)
KeyboardInterrupt
