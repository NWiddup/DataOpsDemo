# Background / Information

This solution logically creates the contents of a Spoke deployment. For this specific example, the Resource Group creation is being done by the 'Hub' deployment.
The Solution specific resources (ie. ADF, SQL Server, SQL Database, Data lake definition, resource firewall rules, etc) are managed with this set of templates.
Config of items WITHIN ADF are done via the normal source controlled manner (for dev) or pipeline deployments (for test/prod).

In an ideal world, noone would ever make any changes from within the portal, and the only way to get changes into any environment is from a DevOps IAC pipeline. However in reality, there will be situations where you need to make changes in the portal (you arent sure what resources need to get deployed, you dont know what the templates look like, you are testing a new service, etc). If you have to make any changes in the portal, you should capture those changes and incorporate them into your IAC templates (make the change, go to the RG > Deployments, copy the template > reverse engineer it with bicep decompile, then add to the base IAC template).
