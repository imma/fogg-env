import os
from chalice import Chalice

f = open(os.path.join(os.path.dirname(__file__), 'chalicelib', '.app-name'))
nm_app = f.read().strip()
f.close()

app = Chalice(app_name=nm_app)
app.debug = True

@app.route("/%s" % nm_app, methods=['GET','POST'])
def index():
    return {'hello': 'world'}
