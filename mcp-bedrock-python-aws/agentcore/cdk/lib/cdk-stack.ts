import {
  AgentCoreApplication,
  AgentCoreMcp,
  type AgentCoreProjectSpec,
  type AgentCoreMcpSpec,
} from '@aws/agentcore-cdk';
import {
  CfnOutput,
  Stack,
  type StackProps,
  aws_bedrockagentcore as bedrockagentcore,
  aws_iam as iam,
} from 'aws-cdk-lib';
import { Construct } from 'constructs';

export interface AgentCoreStackProps extends StackProps {
  /**
   * The AgentCore project specification containing agents, memories, and credentials.
   */
  spec: AgentCoreProjectSpec;
  /**
   * The MCP specification containing gateways and servers.
   */
  mcpSpec?: AgentCoreMcpSpec;
  /**
   * Credential provider ARNs from deployed state, keyed by credential name.
   */
  credentials?: Record<string, { credentialProviderArn: string; clientSecretArn?: string }>;
}

/**
 * CDK Stack that deploys AgentCore infrastructure.
 *
 * This is a thin wrapper that instantiates L3 constructs.
 * All resource logic and outputs are contained within the L3 constructs.
 */
export class AgentCoreStack extends Stack {
  /** The AgentCore application containing all agent environments */
  public readonly application: AgentCoreApplication;

  constructor(scope: Construct, id: string, props: AgentCoreStackProps) {
    super(scope, id, props);

    const { spec, mcpSpec, credentials } = props;

    // Create AgentCoreApplication with all agents
    this.application = new AgentCoreApplication(this, 'Application', {
      spec,
    });

    // Create AgentCoreMcp if there are gateways configured
    if (mcpSpec?.agentCoreGateways && mcpSpec.agentCoreGateways.length > 0) {
      const mcp = new AgentCoreMcp(this, 'Mcp', {
        projectName: spec.name,
        mcpSpec,
        agentCoreApplication: this.application,
        credentials,
        projectTags: spec.tags,
      });

      // Patch Gateway targets to enable SigV4 auth (GATEWAY_IAM_ROLE) and expand permissions
      // This is required because the library defaults iamRoleFallback to false for mcpServer targets,
      // and the auto-generated grant is too narrow for runtime endpoints.
      mcp.node.children.forEach((gateway) => {
        const gatewayAny = gateway as any;
        if (gatewayAny.role && gatewayAny.role instanceof iam.Role) {
          // Grant broad permission to invoke any runtime in this account/region
          // This fixes the issue where the auto-generated grant is too narrow (missing /runtime-endpoint/*)
          gatewayAny.role.addToPolicy(
            new iam.PolicyStatement({
              actions: [
                'bedrock-agentcore:InvokeAgentRuntime',
                'bedrock-agentcore:InvokeAgentRuntimeForUser',
              ],
              resources: [
                `arn:aws:bedrock-agentcore:${this.region}:${this.account}:runtime/*`,
              ],
            }),
          );
        }

        gateway.node.children.forEach((target) => {
          if (target instanceof bedrockagentcore.CfnGatewayTarget) {
            target.addPropertyOverride('CredentialProviderConfigurations', [
              {
                CredentialProviderType: 'GATEWAY_IAM_ROLE',
                CredentialProvider: {
                  IamCredentialProvider: {
                    Service: 'bedrock-agentcore',
                  },
                },
              },
            ]);
          }
        });
      });
    }

    // Stack-level output
    new CfnOutput(this, 'StackNameOutput', {
      description: 'Name of the CloudFormation Stack',
      value: this.stackName,
    });
  }
}
