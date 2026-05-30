-- Универсальное правило: создаем (или обновляем) root для доступа со ВСЕХ внешних сетей
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED WITH mysql_native_password BY 'supersecretpass2026';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;

-- Настройка технического пользователя репликации
DROP USER IF EXISTS 'repl_user'@'%';
CREATE USER 'repl_user'@'%' IDENTIFIED WITH mysql_native_password BY 'my_secure_repl_password_123';
GRANT REPLICATION SLAVE ON *.* TO 'repl_user'@'%';

-- Обязательно сохраняем изменения в памяти СУБД
FLUSH PRIVILEGES;
