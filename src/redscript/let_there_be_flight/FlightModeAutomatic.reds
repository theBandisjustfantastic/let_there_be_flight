public class FlightModeAutomatic extends FlightModeStandard {

  @runtimeProperty("ModSettings.mod", "Let There Be Flight")
  @runtimeProperty("ModSettings.category", "Flight Mode Settings")
  @runtimeProperty("ModSettings.displayName", "Automatic Mode Enabled")
  public let enabled: Bool = false;

  protected let hovering: Float;
  protected let referenceZ: Float;

  public static func Create(component: ref<FlightComponent>) -> ref<FlightModeAutomatic> {
    let self = new FlightModeAutomatic();
    self.Initialize(component);
    self.hovering = 1.0;
    return self;
  }

  public func Initialize(component: ref<FlightComponent>) -> Void {
    super.Initialize(component);
    this.collisionPenalty = 1.0;
  }

  public func Activate() -> Void {
    let normal: Vector4;
    this.referenceZ = this.component.stats.d_position.Z;
    this.component.FindGround(normal);
    this.component.hoverHeight = MaxF(this.component.distance, FlightSettings.GetFloat("hoverModeMinHoverHeight"));
  }
  
  public func GetDescription() -> String = "Automatic";

  public func Update(timeDelta: Float) -> Void {
    let lastHovering = this.hovering;
    let normal: Vector4;
    let foundGround = this.component.FindGround(normal);
    if foundGround {
      this.hovering = ClampF(1.0 - (this.component.distance - FlightSettings.GetFloat("hoverModeMinHoverHeight")) / (FlightSettings.GetFloat("hoverModeMaxHoverHeight") - FlightSettings.GetFloat("hoverModeMinHoverHeight")), 0.0, 1.0);
    } else {
      this.hovering = 0.0;
    }

    if lastHovering == 0.0 && this.hovering > 0.0 {
      this.component.hoverHeight = MaxF(this.component.distance + this.component.lift * timeDelta * FlightSettings.GetFloat("hoverModeLiftFactor"), FlightSettings.GetFloat("hoverModeMinHoverHeight"));
    } else {
      this.component.hoverHeight = MaxF(this.component.hoverHeight + this.component.lift * timeDelta * FlightSettings.GetFloat("hoverModeLiftFactor"), FlightSettings.GetFloat("hoverModeMinHoverHeight"));
    }

    let heightDifference = this.component.hoverHeight - this.component.distance;
    let idealNormal = Vector4.Interpolate(FlightUtils.Up(), normal, this.hovering);

    let hoverCorrection = this.component.hoverGroundPID.GetCorrectionClamped(heightDifference, timeDelta, FlightSettings.GetFloat("hoverClamp"));// / FlightSettings.GetFloat("hoverClamp");
    let liftFactor = LerpF(this.hovering, this.component.lift - this.component.stats.d_velocity.Z * 0.1, hoverCorrection);

    this.UpdateWithNormalLift(timeDelta, idealNormal, liftFactor * FlightSettings.GetFloat("hoverFactor") + (9.81000042) * this.gravityFactor);

    let aeroFactor = Vector4.Dot(this.component.stats.d_forward, this.component.stats.d_direction);
    let yawDirectionality: Float = this.component.stats.d_speedRatio * FlightSettings.GetFloat("automaticModeYawDirectionality");

    let directionFactor = AbsF(Vector4.Dot(this.component.stats.d_forward - this.component.stats.d_direction, this.component.stats.d_right));

    this.force += FlightUtils.Forward() * directionFactor * yawDirectionality * aeroFactor;
    this.force += -this.component.stats.d_localDirection * directionFactor * yawDirectionality * AbsF(aeroFactor);

    if AbsF(this.component.surge) < 1.0 {    
      let velocityDamp: Vector4 = (1.0 - AbsF(this.component.surge)) * FlightSettings.GetFloat("automaticModeAutoBrakingFactor") * this.component.stats.d_localDirection2D * (this.component.stats.d_speed2D / 100.0);
      this.force -= velocityDamp;
    }
  }
}