//
//  CommentHandler.swift
//  SwiftyInsta
//
//  Created by Mahdi Makhdumi on 11/24/18.
//  V. 2.0 by Stefano Bertagno on 7/21/19.
//  Copyright © 2018 Mahdi. All rights reserved.
//

import Foundation

public class CommentHandler: Handler {
    /// Fetch all comments for media.
    public func `for`(media mediaId: String,
                      with paginationParameters: PaginationParameters,
                      updateHandler: PaginationUpdateHandler<MediaCommentsResponseModel>?,
                      completionHandler: @escaping PaginationCompletionHandler<MediaCommentsResponseModel>) {
        pages.fetch(MediaCommentsResponseModel.self,
                    with: paginationParameters,
                    at: { try URLs.getComments(for: mediaId, maxId: $0.nextMaxId ?? "") },
                    updateHandler: updateHandler,
                    completionHandler: completionHandler)
    }
    
    /// Add comment to media.
    public func add(_ comment: String, to mediaId: String, completionHandler: @escaping (Result<CommentResponse, Error>) -> Void) {
        guard let storage = handler.response?.cache?.storage else {
            return completionHandler(.failure(CustomErrors.runTimeError("Invalid `SessionCache` in `APIHandler.respone`. Log in again.")))
        }
        let content = ["_uuid": handler.settings.device.deviceGuid.uuidString,
                       "_uid": storage.dsUserId,
                       "_csrftoken": storage.csrfToken,
                       "user_breadcrumb": String(Date().millisecondsSince1970),
                       "idempotence_token": UUID.init().uuidString,
                       "comment_text": comment,
                       "containermodule": "comments_feed_timeline",
                       "radio_type": "wifi-none"]
        
        let encoder = JSONEncoder()
        let payload = String(data: try! encoder.encode(content), encoding: .utf8)!
        let hash = payload.hmac(algorithm: .SHA256, key: Headers.HeaderIGSignatureValue)
        let signature = "\(hash).\(payload)"
        let body: [String: Any] = [
            Headers.HeaderIGSignatureKey: signature.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!,
            Headers.HeaderIGSignatureVersionKey: Headers.HeaderIGSignatureVersionValue
        ]
        
        requests.decodeAsync(CommentResponse.self,
                             method: .post,
                             url: try! URLs.getPostCommentUrl(mediaId: mediaId),
                             body: .parameters(body),
                             completionHandler: completionHandler)
    }

    /// Delete a comment.
    public func delete(comment commentId: String, in mediaId: String, completionHandler: @escaping (Result<Bool, Error>) -> Void) {
        guard let storage = handler.response?.cache?.storage else {
            return completionHandler(.failure(CustomErrors.runTimeError("Invalid `SessionCache` in `APIHandler.respone`. Log in again.")))
        }
        let body = ["_uuid": handler.settings.device.deviceGuid.uuidString,
                    "_uid": storage.dsUserId,
                    "_csrftoken": storage.csrfToken]
        requests.decodeAsync(BaseStatusResponseModel.self,
                             method: .post,
                             url: try! URLs.getDeleteCommentUrl(mediaId: mediaId, commentId: commentId),
                             body: .parameters(body),
                             completionHandler: { completionHandler($0.map { $0.isOk() }) })
    }

    /// Report a comment.
    public func report(comment commentId: String, in mediaId: String, completionHandler: @escaping (Result<Bool, Error>) -> Void) {
        guard let storage = handler.response?.cache?.storage else {
            return completionHandler(.failure(CustomErrors.runTimeError("Invalid `SessionCache` in `APIHandler.respone`. Log in again.")))
        }
        let body = ["_uuid": handler.settings.device.deviceGuid.uuidString,
                    "_uid": storage.dsUserId,
                    "_csrftoken": storage.csrfToken,
                    "reason": "1",
                    "comment_id": commentId,
                    "media_id": mediaId]
        requests.decodeAsync(BaseStatusResponseModel.self,
                             method: .post,
                             url: try! URLs.reportCommentUrl(mediaId: mediaId, commentId: commentId),
                             body: .parameters(body),
                             completionHandler: { completionHandler($0.map { $0.isOk() }) })
    }
}
