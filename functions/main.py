# Welcome to Cloud Functions for Firebase for Python!
# To get started, simply uncomment the below code or create your own.
# Deploy with `firebase deploy`

import functions_framework
from firebase_admin import firestore, initialize_app

# Firebase admin'i başlat (ilk kez çalıştırıyorsan)
initialize_app()

@functions_framework.http
def start_game(request):
    try:
        data = request.get_json()
        lobby_code = data.get('lobbyCode', '').upper()
        host_id = data.get('hostId')

        if not lobby_code or not host_id:
            return {'success': False, 'error': 'Missing lobbyCode or hostId'}, 400

        db = firestore.client()
        lobby_ref = db.collection('lobbies').document(lobby_code)
        lobby_doc = lobby_ref.get()

        if not lobby_doc.exists:
            return {'success': False, 'error': 'Lobby not found'}, 404

        lobby_data = lobby_doc.to_dict()
        if lobby_data.get('hostUid') != host_id:
            return {'success': False, 'error': 'Only host can start the game'}, 403

        lobby_ref.update({
            'status': 'started',
            'startedAt': firestore.SERVER_TIMESTAMP
        })

        return {'success': True}, 200

    except Exception as e:
        return {'success': False, 'error': str(e)}, 500


# initialize_app()
#
#
# @https_fn.on_request()
# def on_request_example(req: https_fn.Request) -> https_fn.Response:
#     return https_fn.Response("Hello world!")