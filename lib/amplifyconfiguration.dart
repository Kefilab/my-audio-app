const amplifyconfig = '''{
    "UserAgent": "aws-amplify-cli/2.0",
    "Version": "1.0",
    "api": {
        "plugins": {
            "awsAPIPlugin": {
                "dk3m1188as4b1": {
                    "endpointType": "GraphQL",
                    "endpoint": "https://i45mg4iuibgb7fpuvoyhtxshbm.appsync-api.us-west-2.amazonaws.com/graphql",
                    "region": "us-west-2",
                    "authorizationType": "API_KEY",
                    "apiKey": "da2-it32o663kngjjpkpg4l4avlg4i"
                }
            }
        }
    },
    "auth": {
        "plugins": {
            "awsCognitoAuthPlugin": {
                "UserAgent": "aws-amplify-cli/0.1.0",
                "Version": "0.1.0",
                "IdentityManager": {
                    "Default": {}
                },
                "CredentialsProvider": {
                    "CognitoIdentity": {
                        "Default": {
                            "PoolId": "us-west-2:b9d063b6-ef7b-42a1-96c6-ed765b340273",
                            "Region": "us-west-2"
                        }
                    }
                },
                "CognitoUserPool": {
                    "Default": {
                        "PoolId": "us-west-2_1S03qzGZv",
                        "AppClientId": "2nm98mucfc7ik3da07ma8gojm3",
                        "Region": "us-west-2"
                    }
                },
                "Auth": {
                    "Default": {
                        "OAuth": {
                            "WebDomain": "dk3m1188as4b1674638fe-674638fe-main.auth.us-west-2.amazoncognito.com",
                            "AppClientId": "2nm98mucfc7ik3da07ma8gojm3",
                            "SignInRedirectURI": "https://main.d33boiz7wmudx.amplifyapp.com/,http://localhost:3000/",
                            "SignOutRedirectURI": "https://main.d33boiz7wmudx.amplifyapp.com/,http://localhost:3000/",
                            "Scopes": [
                                "phone",
                                "email",
                                "openid",
                                "profile",
                                "aws.cognito.signin.user.admin"
                            ]
                        },
                        "authenticationFlowType": "USER_SRP_AUTH",
                        "mfaConfiguration": "OFF",
                        "mfaTypes": [
                            "SMS"
                        ],
                        "passwordProtectionSettings": {
                            "passwordPolicyMinLength": 8,
                            "passwordPolicyCharacters": []
                        },
                        "signupAttributes": [
                            "EMAIL"
                        ],
                        "socialProviders": [],
                        "usernameAttributes": [
                            "EMAIL"
                        ],
                        "verificationMechanisms": [
                            "EMAIL"
                        ]
                    }
                },
                "AppSync": {
                    "Default": {
                        "ApiUrl": "https://i45mg4iuibgb7fpuvoyhtxshbm.appsync-api.us-west-2.amazonaws.com/graphql",
                        "Region": "us-west-2",
                        "AuthMode": "API_KEY",
                        "ApiKey": "da2-it32o663kngjjpkpg4l4avlg4i",
                        "ClientDatabasePrefix": "dk3m1188as4b1_API_KEY"
                    }
                }
            }
        }
    }
}''';
