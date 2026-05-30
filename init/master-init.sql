-- 1. Стираем старый профиль, если он остался в памяти после прошлых попыток
DROP USER IF EXISTS 'repl_user'@'%';

-- 2. Создаем технического пользователя со старым совместимым шифрованием пароля (mysql_native_password).
-- Это критически важно, так как Слейв без SSL-сертификатов не сможет авторизоваться через стандартный для MySQL 8.0 плагин caching_sha2.
CREATE USER 'repl_user'@'%' IDENTIFIED WITH mysql_native_password BY 'my_secure_repl_password_123';

-- 3. Выдаем пользователю права на чтение бинарных логов репликации
GRANT REPLICATION SLAVE ON *.* TO 'repl_user'@'%';

-- 4. Принудительно сохраняем права в системную память сервера
FLUSH PRIVILEGES;
