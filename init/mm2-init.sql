-- 1. Создаем пользователя репликации для авторизации соседа (первого сервера mm-master1)
DROP USER IF EXISTS 'repl_user'@'%';
CREATE USER 'repl_user'@'%' IDENTIFIED WITH mysql_native_password BY 'my_secure_repl_password_123';
GRANT REPLICATION SLAVE ON *.* TO 'repl_user'@'%';
FLUSH PRIVILEGES;

-- 2. Направляем этот сервер на получение бинарных логов из mm-master1
CHANGE MASTER TO 
  MASTER_HOST='mm-master1',                       -- Указываем имя контейнера первого Мастера
  MASTER_USER='repl_user',                        -- Логин для подключения
  MASTER_PASSWORD='my_secure_repl_password_123',  -- Пароль
  MASTER_LOG_FILE='mysql-bin-m1.000001',          -- Стартовый лог-файл чистого mm-master1 (задан в master1.cnf)
  MASTER_LOG_POS=157;                             -- Стартовая позиция чистого mm-master1

-- 3. Запускаем репликацию
START SLAVE;
