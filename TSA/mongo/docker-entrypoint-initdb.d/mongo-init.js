db = db.getSiblingDB('policy');
db.createCollection('policies');
db.policies.insertMany(
    [
        {
            filename: "example/example/1.0/policy.rego",
            name: "example",
            group: "example",
            version: "1.0",
            repository: "policies",
            locked: false,
            lastUpdate: new Date(),
            rego: `package example.example
		
            allow {
                1 == 1
            }

            taskID := "0123456789abcdef"
            `
        },
        {
            filename: "example/example/2.0/policy.rego",
            name: "example",
            group: "example",
            version: "2.0",
            repository: "policies",
            locked: false,
            lastUpdate: new Date(),
            rego: `package example.example
		
            allow {
                1 == 2
            }
            
            result := input
            `
        },
        {
            filename:"example/loginEmail/1.0/policy.rego",
            name:"loginEmail",
            group:"example",
            version: "1.0",
            repository: "policies",
            locked: false,
            lastUpdate: new Date(),
            data:
            `{
                "trustedEmails": [
                    "example@example.com",
                    "test@example.com",
                    "policy@example.com"
                ]
            }`,
            rego:`package example.loginEmail

            import future.keywords.in

            default allow = false

            allow {
                input.email in data.trustedEmails
            }`
        }
    ]
);

db = db.getSiblingDB('task');
db.createCollection('taskTemplates');
db.taskTemplates.insertMany(
    [
        {
            "name": "exampleTask",
            "url": "https://jsonplaceholder.typicode.com/todos/1",
            "method": "GET",
            "requestPolicy": "",
            "responsePolicy": "",
            "finalPolicy": "",
            "cacheNamespace": "",
            "cacheScope": ""
        },
        {
            "name": "exampleTaskPolicy",
            "url": "",
            "method": "GET",
            "requestPolicy": "policies/example/examplePolicy/1.0",
            "responsePolicy": "",
            "finalPolicy": "",
            "cacheNamespace": "",
            "cacheScope": ""
        },
        {
            "name": "exampleTask2",
            "url": "https://jsonplaceholder.typicode.com/todos/1",
            "method": "GET",
            "requestPolicy": "",
            "responsePolicy": "",
            "finalPolicy": "",
            "cacheNamespace": "",
            "cacheScope": ""
        },
        {
            "name": "didResolve",
            "url": "",
            "method": "GET",
            "requestPolicy": "policies/example/examplePolicy/1.0",
            "responsePolicy": "",
            "finalPolicy": "",
            "cacheNamespace": "",
            "cacheScope": ""
        },
        {
            "name": "failingTask",
            "url": "",
            "requestPolicy": "example",
            "method": null,
            "responsePolicy": "",
            "finalPolicy": "",
            "cacheNamespace": "",
            "cacheScope": ""
        },
        {
            "name": "cacheEventTask",
            "url": "",
            "requestPolicy": "policies/example/cacheEvent/1.0",
            "method": null,
            "responsePolicy": "",
            "finalPolicy": "",
            "cacheNamespace": "",
            "cacheScope": ""
        }
    ]
);

db.createCollection('taskListTemplates');
db.taskListTemplates.insertMany(
    [
        {
            "name": "sequentialTaskList",
            "cacheNamespace": "login",
            "cacheScope": "user",
            "groups": [
                {
                    "execution": "sequential",
                    "tasks": [
                        "exampleTask",
                        "exampleTask2"
                    ]
                }
            ]
        },
        {
            "name": "parallelTaskList",
            "cacheNamespace": "login",
            "cacheScope": "user",
            "groups": [
                {
                    "execution": "parallel",
                    "tasks": [
                        "exampleTask",
                        "exampleTask2"
                    ]
                }
            ]
        },
        {
            "name": "mixedTaskList",
            "cacheNamespace": "login",
            "cacheScope": "user",
            "groups": [
                {
                    "execution": "parallel",
                    "tasks": [
                        "exampleTask",
                        "exampleTask2"
                    ]
                },
                {
                    "execution": "sequential",
                    "tasks": [
                        "exampleTask",
                        "exampleTask2"
                    ]
                }
            ]
        },
        {
            "name": "failingList",
            "groups": [
                {
                    "execution": "parallel",
                    "finalPolicy": "",
                    "tasks": ["failingTask", "exampleTask2"]
                }
            ]
        },
        {
            "name": "testList",
            "groups": [
                {
                    "execution": "sequential",
                    "finalPolicy": "",
                    "tasks": ["getKeyDID", "didResolve"]
                }
            ]
        },
        {
            "name": "failTestListSync",
            "groups": [
                {
                    "execution": "sequential",
                    "finalPolicy": "",
                    "tasks": ["getKeyDID", "failingTask", "exampleTask"]
                }
            ]
        },
        {
            "name": "failTestListAsync",
            "groups": [
                {
                    "execution": "parallel",
                    "finalPolicy": "",
                    "tasks": ["getKeyDID", "failingTask", "exampleTask"]
                }
            ]
        }
    ]
);

db.createCollection('eventTasks');
db.eventTasks.insertMany(
    [
        {
            "key": "did:web:did.actor:alice",
            "namespace": "Login",
            "scope": "Administration",
            "taskName": "cacheEventTask"
        }
    ]
);

db = db.getSiblingDB('infohub');
db.createCollection('exports');
db.exports.insertMany(
    [
        {
            "exportName": "testexport",
            "contexts": ["https://w3id.org/security/suites/jws-2020/v1"],
            "policies": {
                "example/example/1.0": {},
                "example/example/2.0": { "hello": "world" }
            },
            "cacheTTL": 300,
            "key": "key1",
            "keyNamespace": "transit",
            "issuer": "did:web:example.com"
        }
    ]
);
