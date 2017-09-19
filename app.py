import json

def app(event, context):
    return {
        'statusCode': 200,
        'headers': { 'Content-Type': 'application/json' },
        'body': json.dumps({ 'hello': 'hello' })
    }
