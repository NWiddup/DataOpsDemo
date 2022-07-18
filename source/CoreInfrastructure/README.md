# Background / Information

This solution logically would create the Hub deployment. This could include the Core Resource Group, the first VNET, Hub subnet topology, Firewall(s), Bastion host, etc. For this sample, the Core Infrastructure is only deploying a Resource Group and a log analytics workspace (with some solutions in it), as all other content is considered 'Spoke' infrastructure.

To make this solution work, you will need to make sure the Service Principal for your Azure DevOps Project has contributor permissions to your Subscription (or at least permissions to perform action 'Microsoft.Resources/deployments/write' over scope '/subscriptions/GUID').

- Core resources (ie. AAD, VNET Design, ExR/connectivity, etc)
We wont be creating any of these, as it is assumed by this point they already exist
[Hub and Spoke reference with ARM Template and Bicep](https://github.com/mspnp/samples/tree/master/solutions/azure-hub-spoke)
