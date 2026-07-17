@echo =========  Liberando Porta 53  ===================
netsh advfirewall firewall add rule name="Open Port 53" dir=in action=allow protocol=UDP localport=53
@echo =========  Liberando Porta 123  ===================
netsh advfirewall firewall add rule name="Open Port 123" dir=in action=allow protocol=UDP localport=123
@echo =========  Liberando Porta 443  ===================
netsh advfirewall firewall add rule name="Open Port 443" dir=in action=allow protocol=TCP localport=443
netsh firewall set multicastbroadcastresponse ENABLE
@echo =========  Portas Liberadas  ===================
Pause