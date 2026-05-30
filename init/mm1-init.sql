-- 1. Стираем и создаем пользователя репликации для авторизации соседа (второго сервера mm-master2)
DROP USER IF EXISTS 'repl_user'@'%';
CREATE USER 'repl_user'@'%' IDENTIFIED WITH mysql_native_password BY 'my_secure_repl_password_123';
GRANT REPLICATION SLAVE ON *.* TO 'repl_user'@'%';
FLUSH PRIVILEGES;

-- 2. Закольцовываем репликацию: указываем первому серверу скачивать логи со второго сервера
CHANGE MASTER TO 
  MASTER_HOST='mm-master2',                       -- Указываем имя контейнера второго Мастера
  MASTER_USER='repl_user',                        -- Логин для подключения
  MASTER_PASSWORD='my_secure_repl_password_123',  -- Пароль
  MASTER_LOG_FILE='mysql-bin-m2.000001',          -- Стартовый лог-файл чистого mm-master2 (задан в master2.cnf)
  MASTER_LOG_POS=157;                             -- Стартовая позиция чистого mm-master2

-- 3. Запускаем репликацию
START SLAVE;
