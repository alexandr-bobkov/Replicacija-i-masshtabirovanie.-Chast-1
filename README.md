# Домашнее задание к занятию «Репликация и масштабирование. Часть 1» - Бобков Александр




# 📑 Полное домашнее задание: Репликация в MySQL (Теория + Готовая Docker-инфраструктура)

Этот монолитный документ содержит все три выполненных задания (включая дополнительное задание Master-Master), подробные комментарии для каждой строчки и готовые файлы для копирования в вашу рабочую директорию.

---

## 📂 Структура каталога вашего проекта

Перед началом работы создайте на компьютере папку и разложите в неё следующие файлы:
```text
mysql-replication-project/
├── .env                 # Переменные окружения (пароли)
├── docker-compose.yml   # Сценарий оркестрации Docker
├── master.cnf           # Конфигурация Master-сервера
├── slave.cnf            # Конфигурация Slave-сервера
├── master1.cnf          # Конфигурация Master-1 (для Задания 3*)
└── master2.cnf          # Конфигурация Master-2 (для Задания 3*)
```

---

## ЧАСТЬ 1: Теория и ответы на задания

### Задание 1: Различия режимов репликации Master-Slave и Master-Master

**Репликация** — это механизм синхронизации данных между несколькими серверами СУБД для обеспечения отказоустойчивости и распределения нагрузки.


| Критерий сравнения | Режим Master-Slave (Главный — Подчиненный) | Режим Master-Master (Главный — Главный) |
| :--- | :--- | :--- |
| **Распределение ролей** | Четкое разделение. Master выполняет запись и чтение. Slave работает строго в режиме `Read-Only` (Только для чтения). | Сервера абсолютно равноправны. Оба сервера одновременно принимают и чтение, и запись. |
| **Маршрутизация запросов** | Все `INSERT/UPDATE/DELETE` идут на Master. Тяжелые выборки `SELECT` (аналитика, отчеты) распределяются по Slave-серверам. | Приложение может выполнять запись (`INSERT/UPDATE`) на любой из серверов, изменения автоматически синхронизируются. |
| **Отказоустойчивость** | Если падает Slave, система работает. Если падает Master, запись блокируется, пока администратор вручную не переключит роль. | Высокая доступность (High Availability). При падении одного из серверов, трафик моментально перенаправляется на живой Master. |
| **Риск конфликтов** | Отсутствует. Источник изменений всегда один — Master. Данные на Slave гарантированно идентичны. | Высокий. Если одновременно изменить одну строку на разных серверах, возникнет конфликт данных, который остановит репликацию. |
| **Сложность настройки** | Низкая. Стандартный базовый функционал, легко масштабируемый добавлением новых Slave-серверов. | Высокая. Требует тонкой настройки генерации ID (ключей) и логики приложения во избежание коллизий. |

---

## ЧАСТЬ 2: Файлы итоговой конфигурации (Их нужно создать)

### 📄 Файл 1: `.env` (Секретные пароли)
```env
# Главный пароль root-пользователя для управления СУБД
MYSQL_ROOT_PASSWORD=supersecretpass2026

# Имя и пароль служебного аккаунта для авторизации потоков репликации
MYSQL_REPL_USER=repl_user
MYSQL_REPL_PASSWORD=my_secure_repl_password_123
```

### 📄 Файл 2: `master.cnf` (Настройки Мастера для Задания 2)
```ini
[mysqld]
# Уникальный номер сервера в сети репликации. У главного сервера всегда ставится 1.
server-id = 1

# Включаем запись бинарного лога изменений и задаем префикс для его файлов.
log-bin = mysql-bin

# Сервер будет реплицировать только изменения, происходящие внутри базы sakila.
binlog_do_db = sakila
```

### 📄 Файл 3: `slave.cnf` (Настройки Слейва для Задания 2)
```ini
[mysqld]
# Уникальный номер подчиненного сервера. Он обязан отличаться от ID мастера, ставим 2.
server-id = 2

# Включаем ведение ретрансляционного лога (Relay Log) для временного хранения логов мастера.
relay-log = mysql-relay-bin

# Защищаем базу: запрещаем локальное изменение данных на Слейве. Изменения идут только от Мастера.
read_only = 1
```

### 📄 Файл 4: `master1.cnf` (Настройки 1-го Главного для Задания 3*)
```ini
[mysqld]
server-id = 10
log-bin = mysql-bin-m1
# Шаг инкремента для генерации автоинкрементных ID (чтобы ключи не пересекались)
auto_increment_increment = 2
# Начальное смещение. Этот сервер будет создавать строки с ID: 1, 3, 5, 7, 9...
auto_increment_offset = 1
```

### 📄 Файл 5: `master2.cnf` (Настройки 2-го Главного для Задания 3*)
```ini
[mysqld]
server-id = 20
log-bin = mysql-bin-m2
# Шаг инкремента равен двум, как и на первом сервере
auto_increment_increment = 2
# Начальное смещение равно двум. Этот сервер будет создавать строки с ID: 2, 4, 6, 8, 10...
auto_increment_offset = 2
```

### 📄 Файл 6: `docker-compose.yml` (Сценарий оркестрации всей лабораторной работы)
```yaml
version: '3.8'

networks:
  replication_net:
    driver: bridge # Создаем общую изолированную сеть для общения серверов по именам

services:
  # --- Инфраструктура для Задания 2 (Master-Slave) ---
  mysql-master:
    image: mysql:8.0
    container_name: mysql-master
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD} # Забираем пароль из файла .env
    ports:
      - "3306:3306" # Проброс стандартного порта наружу
    volumes:
      - ./master.cnf:/etc/mysql/conf.d/master.cnf # Монтируем настройки
    networks:
      - replication_net

  mysql-slave:
    image: mysql:8.0
    container_name: mysql-slave
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
    ports:
      - "3307:3306" # Пробрасываем слейв наружу на порт 3307 компьютера
    volumes:
      - ./slave.cnf:/etc/mysql/conf.d/slave.cnf
    depends_on:
      - mysql-master # Слейв ждет старта мастера
    networks:
      - replication_net

  # --- Дополнительная инфраструктура для Задания 3* (Master-Master) ---
  mm-master1:
    image: mysql:8.0
    container_name: mm-master1
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
    ports:
      - "3308:3306" # Доступен на порту 3308 хоста
    volumes:
      - ./master1.cnf:/etc/mysql/conf.d/master1.cnf
    networks:
      - replication_net

  mm-master2:
    image: mysql:8.0
    container_name: mm-master2
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
    ports:
      - "3309:3306" # Доступен на порту 3309 хоста
    volumes:
      - ./master2.cnf:/etc/mysql/conf.d/master2.cnf
    networks:
      - replication_net
```

---

## ЧАСТЬ 3: Пошаговая инструкция по запуску и настройке

### Шаг 1. Запуск контейнеров в Docker
Откройте терминал на вашем компьютере в папке проекта и выполните команду:
```bash
docker compose up -d
# Конманда скачает образы и поднимет сразу 4 сервера баз данных в фоновом режиме.
```

---

### Шаг 2. Настройка Задания 2 (Master-Slave)

**1. Подключаемся к Мастеру (Компьютер: порт 3306, Пароль: из `.env`) и создаем пользователя:**
```sql
CREATE USER 'repl_user'@'%' IDENTIFIED BY 'my_secure_repl_password_123';
GRANT REPLICATION SLAVE ON *.* TO 'repl_user'@'%';
FLUSH PRIVILEGES;

-- Запоминаем значения из колонок File и Position:
SHOW MASTER STATUS; 
```

**2. Подключаемся к Слейву (Компьютер: порт 3307, Пароль: из `.env`) и связываем его:**
```sql
CHANGE MASTER TO 
  MASTER_HOST='mysql-master', -- Docker сам сопоставит это имя с IP-адресом контейнера мастера
  MASTER_USER='repl_user',
  MASTER_PASSWORD='my_secure_repl_password_123',
  MASTER_LOG_FILE='mysql-bin.000001', -- Подставьте имя файла из SHOW MASTER STATUS мастера
  MASTER_LOG_POS=154;                 -- Подставьте позицию из SHOW MASTER STATUS мастера

START SLAVE;
```

**📸 Как сделать скриншот для сдачи Задания 2:**
Запустите на Слейве команду: `SHOW SLAVE STATUS\G;` и сделайте скриншот. Преподаватель должен увидеть строчки:
*   `Slave_IO_Running: Yes`
*   `Slave_SQL_Running: Yes`

---

### Шаг 3. Настройка Задания 3* (Master-Master)

В схеме Master-Master настройки выполняются циклично. Каждый сервер должен стать слейвом для своего соседа.

**1. Настройка mm-master1 (Порт 3308):**
```sql
-- Создаем пользователя репликации для соседа:
CREATE USER 'repl_user1'@'%' IDENTIFIED BY 'my_secure_repl_password_123';
GRANT REPLICATION SLAVE ON *.* TO 'repl_user1'@'%';
FLUSH PRIVILEGES;

-- Запоминаем файл и позицию этого сервера (они нужны для настройки master2):
SHOW MASTER STATUS;
```

**2. Настройка mm-master2 (Порт 3309):**
```sql
-- Создаем пользователя репликации для соседа:
CREATE USER 'repl_user2'@'%' IDENTIFIED BY 'my_secure_repl_password_123';
GRANT REPLICATION SLAVE ON *.* TO 'repl_user2'@'%';
FLUSH PRIVILEGES;

-- Запоминаем файл и позицию этого сервера (они нужны для настройки master1):
SHOW MASTER STATUS;

-- Направляем этот сервер (master2) на чтение логов из master1:
CHANGE MASTER TO 
  MASTER_HOST='mm-master1',
  MASTER_USER='repl_user1',
  MASTER_PASSWORD='my_secure_repl_password_123',
  MASTER_LOG_FILE='mysql-bin-m1.000001', -- Логовый файл от mm-master1
  MASTER_LOG_POS=154;                    -- Позиция от mm-master1

START SLAVE;
```

**3. Возвращаемся на mm-master1 (Порт 3308) и закольцовываем репликацию:**
```sql
-- Направляем первый сервер на получение изменений из второго:
CHANGE MASTER TO 
  MASTER_HOST='mm-master2',
  MASTER_USER='repl_user2',
  MASTER_PASSWORD='my_secure_repl_password_123',
  MASTER_LOG_FILE='mysql-bin-m2.000001', -- Логовый файл от mm-master2
  MASTER_LOG_POS=154;                    -- Позиция от mm-master2

START SLAVE;
```

**📸 Как сделать скриншот для сдачи Задания 3\*:**
1. Запустите команду `SHOW SLAVE STATUS\G;` на обоих серверах (`mm-master1` и `mm-master2`). Сделайте скриншот статусов (везде должны гореть `Yes`).

