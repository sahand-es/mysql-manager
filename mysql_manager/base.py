import pymysql

class BaseManager: 
    def __init__(self, host: str, user: str, password: str, port: int=3306) -> None:
        self.host = host 
        self.port = port
        self.user = user
        self.password = password
    
    def _log(self, msg) -> None:
        print("host: " + self.host + ", " + msg)
 
    def _get_db(self):
        db = None 
        try:
            db = pymysql.Connection(
                host=self.host,
                port=self.port,
                user=self.user,
                password=self.password,
                cursorclass=pymysql.cursors.DictCursor,
            )
        except Exception as e: 
            print(e)
            return None
        return db 

    def get_info(self, command: str) -> dict: 
        db = self._get_db()
        if db is None: 
            print("Could not connect to mysql")
            return None
        
        result = None 
        with db: 
            with db.cursor() as cursor:
                try: 
                    cursor.execute(command)
                    result = cursor.fetchone()
                    # print(result)
                except Exception as e:
                    print(e) 
                    return None
                
        return result
        
    def ping(self) -> bool:
        db = self._get_db()
        if db is None: 
            print("Could not connect to server")
            return False
        
        with db:
            try: 
                db.ping(reconnect=True)
            except: 
                return False 
        return True 

