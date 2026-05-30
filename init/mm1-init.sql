-- Универсальное правило: открываем root доступ со всех внешних хостов
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED WITH mysql_native_password BY 'supersecretpass2026';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;

-- Настройка пользователя репликации
DROP USER IF EXISTS 'repl_user'@'%';
CREATE USER 'repl_user'@'%' IDENTIFIED WITH mysql_native_password BY 'my_secure_repl_password_123';
GRANT REPLICATION SLAVE ON *.* TO 'repl_user'@'%';
FLUSH PRIVILEGES;

-- Автоматическая привязка к соседу
CHANGE MASTER TO MASTER_HOST='mm-master2', MASTER_USER='repl_user', MASTER_PASSWORD='my_secure_repl_password_123', MASTER_LOG_FILE='mysql-bin-m2.000001', MASTER_LOG_POS=157;
START SLAVE;
