class AppController
  attr_accessor :listView

  TEXT = [
"Enter at your peril, past the vaulted door. Impossible things will happen that the world's never seen before. In Dexter's laboratory lives the smartest boy you've ever seen, but Dee Dee blows his experiments to Smithereens! There's gloom and doom when things go boom in Dexter's lab!",

"Come and knock on our door. We've been waiting for you. Where the kisses are hers and hers and his, three's company, too! Come and dance on our floor. Take a step that is new. We've a lovable space that needs your face, three's company, too! You'll see that life is a ball again and laughter is callin' for you. Down at our rendezvous, three's company, too!",

"Making your way in the world today takes everything you've got. Taking a break from all your worries, sure would help a lot. Wouldn't you like to get away? Sometimes you want to go where everybody knows your name, and they're always glad you came. You wanna be where you can see, our troubles are all the same. You wanna be where everybody knows your name. You wanna go where people know, people are all the same, you wanna go where everybody knows your name.",

"It's time to play the music, it's time to light the lights. It's time to meet the Muppets on the Muppet Show tonight! It's time to put on makeup, it's time to dress up right. It's time to raise the curtain on the Muppet Show tonight. Why do we always come here? I guess we'll never know. It's like a kind of torture to have to watch the show! And now let's get things started - why don't you get things started? It's time to get things started on the most sensational inspirational celebrational Muppetational... This is what we call the Muppet Show!"
  ]

  def awakeFromNib
    models = TEXT.map { |t| Model.new(t) }
    models[2] = CollapsibleModel.new("I can collapse!", [models[2]])
    @listView.representedObjects = models
  end
end
