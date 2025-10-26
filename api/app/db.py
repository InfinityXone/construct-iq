from os import getenv
import psycopg
from psycopg.rows import dict_row
DATABASE_URL = getenv("DATABASE_URL","postgresql://ciq:ciqpass@db:5432/ciq")
def connect():
    return psycopg.connect(DATABASE_URL, row_factory=dict_row)
